# coding: utf-8
# Ref.: Dear ImGuiの使い方まとめ
# https://qiita.com/mizuma/items/73218dab2f6b022b0227

####################################################################################################

module ImGuiDemo

  @@font = nil

  def self.AddFont(ttf_filepath = './jpfont/GenShinGothic-Normal.ttf')
    io = ImGuiIO.new(ImGui::GetIO())
    ImGui::FontAtlas_AddFontDefault(io[:Fonts])
    # ?? GetGlyphRangesJapanese fails to render Japanese Kanji characters '漱', '吾', '獰', '逢', '頃' and '咽' in 'jpfont.txt'.
    # japanese_font = ImGui::FontAtlas_AddFontFromFileTTF(io[:Fonts], './jpfont/GenShinGothic-Normal.ttf', 24.0, nil, ImGui::FontAtlas_GetGlyphRangesJapanese(io[:Fonts]))
    @@font = ImGui::FontAtlas_AddFontFromFileTTF(io[:Fonts], ttf_filepath, 24.0, nil, ImGui::FontAtlas_GetGlyphRangesChineseFull(io[:Fonts]))
  end

  def self.GetFont()
    return @@font
  end

  def self.SetGlobalScale(scale = 1.0)
    io = ImGuiIO.new(ImGui::GetIO())
    io[:FontGlobalScale] = scale # フォントの大きさを一括で変更できます。
    style = ImGui::GetStyle()
    ImGui::ImGuiStyle_ScaleAllSizes(style, scale) # UIの大きさを一括で変更できます。
  end

end # module ImGuiDemo

####################################################################################################

module ImGuiDemo::BasicWindow
  def self.Show(is_open = nil)
    ImGui::PushFont(ImGuiDemo::GetFont())
    ImGui::Begin("ウィンドウタイトル")

    ImGui::Text("通常の文章")
    ImGui::TextColored(ImVec4.create(1.0,0.0,1.0,1.0), "2行目") # 色付き文字。ImVec4(R,G,B,A)で色指定します。
    ImGui::BulletText("白い丸が先頭に付いた文章\n\"改行\"した文章") # \n で改行します。 " を使いたいときは \" のようにします。

    ImGui::Indent()
    ImGui::BulletText("インデントされた文章")
    ImGui::TextDisabled("無効な文字") # グレーで表示されます。
    ImGui::Unindent()

    ImGui::Separator()
    ImGui::TextWrapped("とても長い文章でもウィンドウの横幅に応じて自動的に折り返して次の行に表示してくれます")
    ImGui::NewLine() # 空白行を追加します。

    ImGui::PushTextWrapPos(200.0) # 折り返しさせる幅を指定します。
    ImGui::Text("PushTextWrapPosからPopTextWrapPosまでの間のTextは折り返して表示されます")
    # ... 
    # ここに追加する文章はすべて PushTextWrapPos(200.0f) の影響を受けます。
    # ...
    ImGui::PopTextWrapPos()

    ImGui::End()
    ImGui::PopFont()
  end
end

####################################################################################################

module ImGuiDemo::ButtonAndCheckboxWindow
  @@is_open = FFI::MemoryPointer.new(:bool, 1) # static bool is_open = true;
  def self.Show(is_open = nil)
    ImGui::PushFont(ImGuiDemo::GetFont())
    ImGui::Begin("ボタンとチェックボックス")
    if ImGui::Button("Open/Close")
      # ボタンがクリックされるとここにきます。
      @@is_open.write(:bool, !@@is_open.read(:bool))
    end

    ImGui::SameLine() # 次に書くUIパーツを現在と同じ行に配置します。

    # チェックボックスがクリックされるとis_openが反転し、trueならチェックマークが表示されます。
    ImGui::Checkbox("Open/Close", @@is_open)

    if @@is_open.read(:bool) == true
      # is_openがtrueなら"別のウィンドウ"が表示されます。
      ImGui::Begin("別のウィンドウ@ボタンとチェックボックス", @@is_open)
      ImGui::Text("Hello")
      ImGui::End()
    end
    ImGui::End()
    ImGui::PopFont()
  end
end

####################################################################################################

module ImGuiDemo::RadioButtonWindow
  @@radio = FFI::MemoryPointer.new(:int, 1) # static int radio = 0;
  def self.Show(is_open = nil)
    ImGui::PushFont(ImGuiDemo::GetFont())
    ImGui::Begin("ラジオボタン")
    # ラジオボタンがクリックされると第3引数の整数が第2引数のradioに格納されます。
    ImGui::RadioButtonIntPtr("ラジオボタン 0", @@radio, 0); ImGui::SameLine() # TODO define overload to hide RadioButtonIntPtr
    ImGui::RadioButtonIntPtr("ラジオボタン 1", @@radio, 1); ImGui::SameLine()
    ImGui::RadioButtonIntPtr("ラジオボタン 2", @@radio, 2);

    ImGui::Text("ラジオボタンは%dを選択しています", :int, @@radio.read(:int))
  end
end

####################################################################################################

module ImGuiDemo::ArrowButtonWindow
  @@counter = FFI::MemoryPointer.new(:int, 1) # static int counter = 0;
  def self.Show(is_open = nil)
    ImGui::PushFont(ImGuiDemo::GetFont())
    ImGui::Begin("長押しで急増/急減する三角矢印ボタン")
    ImGui::PushButtonRepeat(true)
    if ImGui::ArrowButton("##left", ImGuiDir_Left)
      @@counter.write(:int, @@counter.read(:int) - 1) # == counter--;
    end
    ImGui::SameLine();
    if ImGui::ArrowButton("##right", ImGuiDir_Right)
      @@counter.write(:int, @@counter.read(:int) + 1) # == counter++;
    end
    ImGui::PopButtonRepeat()
    ImGui::SameLine()
    ImGui::Text("%d", :int, @@counter.read(:int))
    ImGui::End()
    ImGui::PopFont()
  end
end

####################################################################################################

module ImGuiDemo::DropdownListAndInputWindow
  @@items = FFI::MemoryPointer.new(:pointer, 3)
  @@items_string = ["AAA", "BBB", "CCC"].map! {|s| FFI::MemoryPointer.from_string(s)}
  @@items.write_array_of_pointer(@@items_string)

  @@item_current = FFI::MemoryPointer.new(:int, 1) # static int item_current = 0; // 0なら"AAA", 1なら"BBB", 2なら"CCC"
  @@str0 = FFI::MemoryPointer.new(:char, 128) # static char str0[128] = "";
  @@str1 = FFI::MemoryPointer.new(:char, 128) # static char str1[128] = "";
  @@i0 = FFI::MemoryPointer.new(:int, 1) # static int i0 = 123;
  @@f0 = FFI::MemoryPointer.new(:float, 1) # static float f0 = 0.001f;
  @@vec3 = FFI::MemoryPointer.new(:float, 3) # static float vec3[3] = { 0.10f, 0.20f, 0.30f};
  def self.Show(is_open = nil)
    ImGui::PushFont(ImGuiDemo::GetFont())
    ImGui::Begin("ドロップダウンリストと文章入力欄/数字入力欄")
    ImGui::LabelText("ラベル", "値")

    ImGui::ComboStr_arr("ドロップダウンリスト##1", @@item_current, @@items, 3)
    # 別の書き方として \0 で項目を区切って書く方法があります。
    ImGui::ComboStr("ドロップダウンリスト##2", @@item_current, "AAA\0BBB\0CCC\0")

    item_current = @@item_current.read(:int)
    items = @@items.get_array_of_pointer(0, 3)
    ImGui::Text("現在選択されているのは %d で、%s です", :int, item_current, :string, items[item_current].read_string)

    #ImGui::InputText("文章入力欄##1", @@str0, @@str0.length)
    #ImmGui::InputTextWithHint("文章入力欄##2", "空欄時に表示される文章を指定できます", @@str1, @@str1.length)
    ImGui::End()
    ImGui::PopFont()
  end
end

####################################################################################################

