require_relative 'common'

class SourceWriter

  INDENT = 2

  attr_reader :indent, :ostream

  def initialize(ostream)
    @indent = 0
    @ostream = ostream
  end

  def push_indent()
    @indent += INDENT
  end

  def pop_indent()
    @indent -= INDENT
    @indent = 0 if @indent < 0
  end

  def write(str)
    ostream.print("#{' ' * @indent}" + str)
  end

  def newline()
    ostream.puts()
  end

end

module Generator

  def self.write_enum(out, enum)
    out.write("# " + enum.name)
    out.newline
    enum.members.each do |m|
      out.write("#{m.name} = #{m.value} # #{m.original}\n")
    end
    out.newline
  end

  def self.write_struct(out, struct)
    out.write("class #{struct.name} < FFI::Struct\n")
    out.push_indent
    out.write("layout(\n")
    out.push_indent
    struct.members.each do |m|
      tail = if m.equal?(struct.members.last)
               "\n"
             else
               ",\n"
             end
      args = ""
      if m.is_array
        args = if m.type.to_s.start_with?('Im')
                 "[#{m.type}.by_value, #{m.size}]"
               else
                 "[:#{m.type}, #{m.size}]"
               end
      else
        args = if m.type.to_s.start_with?('Im')
                 "#{m.type}.by_value"
               else
                 ":#{m.type}"
               end
      end
      out.write(":#{m.name}, #{args}#{tail}")
    end
    out.pop_indent
    out.write(")\n")
    out.pop_indent
    out.write("end\n\n")
  end

  def self.write_function(out, func)

    func.args.map! do |arg|
      if arg.type.to_s.start_with?('Im')
        arg.type.to_s + '.by_value'
      else
        ':' + arg.type.to_s
      end
    end

    func.retval = if func.retval.to_s.start_with?('Im')
                    func.retval.to_s + '.by_value'
                  else
                    ':' + func.retval.to_s
                  end

    func_name_ruby = func.name
    func_name_c = func.name
    if func.name.start_with?('ig')
      func_name_ruby = func_name_c.gsub(/^ig/, '')
    elsif func.name.start_with?('ImGui_')
      func_name_ruby = func_name_c.gsub(/^ImGui_/, '')
    elsif func.name.start_with?('ImFontAtlas_')
      func_name_ruby = func_name_c.gsub(/^Im/, '')
    end
    out.write("attach_function :#{func_name_ruby}, :#{func_name_c}, [#{func.args.join(', ')}], #{func.retval}\n")
  end

end # module Generator


if __FILE__ == $0
  #
  # Setup
  #
  ImGuiBindings.build_ffi_typedef_map( '../cimgui/generator/output/typedefs_dict.json' )
  enums_map = ImGuiBindings.build_enum_map( '../cimgui/generator/output/structs_and_enums.json' )
  structs_map = ImGuiBindings.build_struct_map( '../cimgui/generator/output/structs_and_enums.json' )
  funcs_base_map = ImGuiBindings.build_function_map( '../cimgui/generator/output/definitions.json' )
  funcs_impl_map = ImGuiBindings.build_function_map( '../cimgui/generator/output/impl_definitions.json' )

  # Omit needless/unusable data
  omit_structs = [
    'CustomRect',
    'GlyphRangesBuilder',
    'ImDrawChannel',
    'ImDrawCmd',
    'ImDrawData',
    'ImDrawList',
    'ImDrawVert',
  # 'ImFont',
  # 'ImFontAtlas',
  # 'ImFontConfig',
    'ImFontGlyph',
    'ImGuiInputTextCallbackData',
    'ImGuiListClipper',
    'ImGuiOnceUponAFrame',
    'ImGuiPayload',
    'ImGuiSizeCallbackData',
    'ImGuiStorage',
    'ImGuiTextBuffer',
    'ImGuiTextFilter',
    'TextRange',
    'Pair',
  # 'ImVector',
  ]
  structs_map.delete_if {|struct| omit_structs.include?(struct.name)}

  funcs_base_map.delete_if {|func| !(func.name.start_with?('ig') || func.name.start_with?('ImFontAtlas_'))} # end-user API only
  funcs_impl_map.delete_if {|func| func.name.include?('OpenGL3')} # not supported yet
  funcs_impl_map.delete_if {|func| func.name.include?('SDL2')} # not supported yet

  #
  # Write to actual source code
  #
  output_path = '../'
  output_filename = 'imgui_glfw_opengl2.rb'
  File.open(output_path + output_filename, 'wb') do |file|
    #
    # Prologue
    #
    out = SourceWriter.new(file)
    out.write(<<-EOS)
# imgui-bindings : Yet another ImGui wrapper for Ruby
#
# * https://github.com/vaiorabbit/ruby-imgui
#
# [NOTICE] This is an automatically generated file.

require 'ffi'
    EOS
    out.newline

    #
    # Enums
    #
    enums_map.each do |enum|
      Generator.write_enum(out, enum)
    end
    out.newline

    #
    # Structs
    #

    ['ImVec2', 'ImVec4'].each do |name| # for forward declaration
      Generator.write_struct(out, structs_map.find{|struct| struct.name == name})
      structs_map.delete_if {|struct| struct.name == name}
    end

    structs_map.each do |struct|
      Generator.write_struct(out, struct)
    end

    #
    # Functions
    #
    out.write("module ImGui\n")
    out.newline
    out.push_indent
    out.write("extend FFI::Library\n")
    out.newline

    out.pop_indent
    out.write(<<-EOS)
  @@imgui_import_done = false

  def self.load_lib(libpath = './imgui_glfw_opengl2.dylib')
    ffi_lib_flags :now, :global
    ffi_lib libpath
    import_symbols() unless @@imgui_import_done
  end

    EOS

    out.push_indent
    out.write("def self.import_symbols()")
    out.newline

    out.push_indent
    [funcs_base_map, funcs_impl_map].each do |funcs_map|
      funcs_map.each do |func|
        Generator.write_function(out, func)
      end
    end
    out.pop_indent

    out.write("end # self.import_symbols\n")
    out.newline

    #
    # Epilogue
    #
    out.pop_indent
    out.write("end # module ImGui\n")
  end

end

