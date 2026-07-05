#include "GumboParser.hpp"
#include <gtest/gtest.h>

TEST(GumboParserTest, TagRemappings) {
  EXPECT_EQ(GumboParser::normalizeHtml("<strong>x</strong>"), "<b>x</b>");
  EXPECT_EQ(GumboParser::normalizeHtml("<em>x</em>"), "<i>x</i>");
  EXPECT_EQ(GumboParser::normalizeHtml("<del>x</del>"), "<s>x</s>");
  EXPECT_EQ(GumboParser::normalizeHtml("<strike>x</strike>"), "<s>x</s>");
  EXPECT_EQ(GumboParser::normalizeHtml("<ins>x</ins>"), "<u>x</u>");
  EXPECT_EQ(GumboParser::normalizeHtml("<pre>x</pre>"),
            "<codeblock><p>x</p></codeblock>");
}

TEST(GumboParserTest, GoogleDocsWrapper) {
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<b id=\"docs-internal-guid-1234567890\">x</b>"),
            "x");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<b id=\"docs-internal-guid-1234567890\"></b>"),
            "");
}

TEST(GumboParserTest, KeepsSpacesAroundAdjacentInlineRuns) {
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<p>Inline code adjacency:\n"
          "  <code>first code</code>\n"
          "  normal text\n"
          "  <code>second code</code>\n"
          "  <a href=\"https://example.com\"><code>linked "
          "code</code></a>\n"
          "  trailing text.</p>"),
      "<p>Inline code adjacency: <code>first code</code> normal text "
      "<code>second code</code> <a href=\"https://example.com\"><code>linked "
      "code</code></a> trailing text.</p>");
}

TEST(GumboParserTest, KeepsPunctuationAfterMention) {
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<blockquote>\n"
          "  Quote inside ordered list item with\n"
          "  <mention text=\"@Ordered Quote\" indicator=\"@\" "
          "id=\"ordered-quote\" type=\"user\">@Ordered Quote</mention>\n"
          "  and\n"
          "  <mention text=\"#ordered-quote\" indicator=\"#\" "
          "id=\"ordered-quote-channel\" "
          "type=\"channel\">#ordered-quote</mention>.\n"
          "</blockquote>"),
      "<blockquote><p>Quote inside ordered list item with <mention "
      "id=\"ordered-quote\" text=\"@Ordered Quote\" indicator=\"@\">@Ordered "
      "Quote</mention> and <mention id=\"ordered-quote-channel\" "
      "text=\"#ordered-quote\" indicator=\"#\">#ordered-quote</mention>.</p>"
      "</blockquote>");
}

TEST(GumboParserTest, TagOmissions) {
  EXPECT_EQ(
      GumboParser::normalizeHtml("<meta name='author' content='John Doe'>"),
      "");
  EXPECT_EQ(GumboParser::normalizeHtml("<style></style>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<script></script>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<title></title>"), "");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<link rel='stylesheet' href='styles.css'>"),
      "");
  EXPECT_EQ(GumboParser::normalizeHtml("<html></html>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<body></body>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<head></head>"), "");

  // Nested tags
  EXPECT_EQ(
      GumboParser::normalizeHtml("<html><head></head><body></body></html>"),
      "");
  EXPECT_EQ(GumboParser::normalizeHtml("<html><body><p>x</p></body></html>"),
            "<p>x</p>");
  EXPECT_EQ(GumboParser::normalizeHtml("<html><p>x</p></html>"), "<p>x</p>");
  EXPECT_EQ(GumboParser::normalizeHtml("<body><p>x</p></body>"), "<p>x</p>");
}

TEST(GumboParserTest, TableOmissions) {
  EXPECT_EQ(GumboParser::normalizeHtml("<table></table>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<thead></thead>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<tbody></tbody>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<tfoot></tfoot>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<tr></tr>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<td></td>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<th></th>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<caption></caption>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<colgroup></colgroup>"), "");
  EXPECT_EQ(GumboParser::normalizeHtml("<col></col>"), "");

  EXPECT_EQ(GumboParser::normalizeHtml(
                "<table "
                "style=\"width:100%\"><tr><td>Emil</td><td>Tobias</"
                "td><td>Linus</td></tr></table>"),
            "<p>Emil Tobias Linus</p>");

  EXPECT_EQ(GumboParser::normalizeHtml(
                "<table><tr><td>Emil</td><td>Tobias</td><td>Linus</td></tr>"
                "<tr><td>16</td><td>14</td><td>10</td></tr></table>"),
            "<p>Emil Tobias Linus</p><p>16 14 10</p>");

  EXPECT_EQ(GumboParser::normalizeHtml(
                "<table><tr><th>Person 1</th><th>Person 2</th><th>Person "
                "3</th></tr><tr><td>Emil</td><td>Tobias</td><td>Linus</td></"
                "tr><tr><td>16</td><td>14</td><td>10</td></tr></table>"),
            "<p>Person 1 Person 2 Person 3</p><p>Emil Tobias Linus</p><p>16 14 "
            "10</p>");
}

TEST(GumboParserTest, SpanRemappings) {
  // Bold
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"font-weight: bold;\">x</span>"),
      "<b>x</b>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"font-weight: bold\">x</span>"),
      "<b>x</b>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style='font-weight: bold'>x</span>"),
      "<b>x</b>");

  // Italic
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style=\"font-style: italic;\">x</span>"),
            "<i>x</i>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"font-style: italic\">x</span>"),
      "<i>x</i>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style='font-style: italic'>x</span>"),
      "<i>x</i>");

  // Underline
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style=\"text-decoration: underline;\">x</span>"),
            "<u>x</u>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style=\"text-decoration: underline\">x</span>"),
            "<u>x</u>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='text-decoration: underline'>x</span>"),
            "<u>x</u>");

  // Strikethrough
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style=\"text-decoration: line-through;\">x</span>"),
            "<s>x</s>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style=\"text-decoration: line-through\">x</span>"),
            "<s>x</s>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='text-decoration: line-through'>x</span>"),
            "<s>x</s>");

  // Bold and Italic
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<span style=\"font-weight: bold; font-style: italic;\">x</span>"),
      "<b><i>x</i></b>");
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<span style=\"font-weight: bold; font-style: italic\">x</span>"),
      "<b><i>x</i></b>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='font-weight: bold; font-style: italic'>x</span>"),
            "<b><i>x</i></b>");

  // Italic and Bold
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<span style=\"font-style: italic; font-weight: bold;\">x</span>"),
      "<b><i>x</i></b>");
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<span style=\"font-style: italic; font-weight: bold\">x</span>"),
      "<b><i>x</i></b>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='font-style: italic; font-weight: bold'>x</span>"),
            "<b><i>x</i></b>");

  // Bold and Underline
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"font-weight: bold; "
                                 "text-decoration: underline;\">x</span>"),
      "<b><u>x</u></b>");
  EXPECT_EQ(GumboParser::normalizeHtml("<span style=\"font-weight: bold; "
                                       "text-decoration: underline\">x</span>"),
            "<b><u>x</u></b>");
  EXPECT_EQ(GumboParser::normalizeHtml("<span style='font-weight: bold; "
                                       "text-decoration: underline'>x</span>"),
            "<b><u>x</u></b>");

  // Underline and Bold
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"text-decoration: underline; "
                                 "font-weight: bold;\">x</span>"),
      "<b><u>x</u></b>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"text-decoration: underline; "
                                 "font-weight: bold\">x</span>"),
      "<b><u>x</u></b>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style='text-decoration: underline; "
                                 "font-weight: bold'>x</span>"),
      "<b><u>x</u></b>");

  // Bold and Strikethrough
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"font-weight: bold; "
                                 "text-decoration: line-through;\">x</span>"),
      "<b><s>x</s></b>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"font-weight: bold; "
                                 "text-decoration: line-through\">x</span>"),
      "<b><s>x</s></b>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style='font-weight: bold; "
                                 "text-decoration: line-through'>x</span>"),
      "<b><s>x</s></b>");

  // Strikethrough and Bold
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"text-decoration: line-through; "
                                 "font-weight: bold;\">x</span>"),
      "<b><s>x</s></b>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"text-decoration: line-through; "
                                 "font-weight: bold\">x</span>"),
      "<b><s>x</s></b>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style='text-decoration: line-through; "
                                 "font-weight: bold'>x</span>"),
      "<b><s>x</s></b>");

  // Underline and Strikethrough
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"text-decoration: underline; "
                                 "text-decoration: line-through;\">x</span>"),
      "<u><s>x</s></u>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"text-decoration: underline; "
                                 "text-decoration: line-through\">x</span>"),
      "<u><s>x</s></u>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style='text-decoration: underline; "
                                 "text-decoration: line-through'>x</span>"),
      "<u><s>x</s></u>");

  // Strikethrough and Underline
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"text-decoration: line-through; "
                                 "text-decoration: underline;\">x</span>"),
      "<u><s>x</s></u>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style=\"text-decoration: line-through; "
                                 "text-decoration: underline\">x</span>"),
      "<u><s>x</s></u>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<span style='text-decoration: line-through; "
                                 "text-decoration: underline'>x</span>"),
      "<u><s>x</s></u>");

  // Combined
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style=\"font-weight: bold; font-style: italic; "
                "text-decoration: underline;\">x</span>"),
            "<b><i><u>x</u></i></b>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style=\"font-weight: bold; font-style: italic; "
                "text-decoration: underline\">x</span>"),
            "<b><i><u>x</u></i></b>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='font-weight: bold; font-style: italic; "
                "text-decoration: underline'>x</span>"),
            "<b><i><u>x</u></i></b>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='font-weight: bold; text-decoration: underline; "
                "font-style: italic;'>x</span>"),
            "<b><i><u>x</u></i></b>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='text-decoration: underline; font-weight: bold; "
                "font-style: italic;'>x</span>"),
            "<b><i><u>x</u></i></b>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='text-decoration: line-through; font-weight: "
                "bold; font-style: italic;'>x</span>"),
            "<b><i><s>x</s></i></b>");
}

TEST(GumboParserTest, EnrichedTagRemappings) {
  // Block elements
  EXPECT_EQ(GumboParser::normalizeHtml("<codeblock>x</codeblock>"),
            "<codeblock><p>x</p></codeblock>");
  EXPECT_EQ(GumboParser::normalizeHtml("<codeblock><p>x</p></codeblock>"),
            "<codeblock><p>x</p></codeblock>");
  EXPECT_EQ(GumboParser::normalizeHtml("<blockquote>x</blockquote>"),
            "<blockquote><p>x</p></blockquote>");
  EXPECT_EQ(GumboParser::normalizeHtml("<blockquote><p>x</p></blockquote>"),
            "<blockquote><p>x</p></blockquote>");

  // Headings
  EXPECT_EQ(GumboParser::normalizeHtml("<h1>x</h1>"), "<h1>x</h1>");
  EXPECT_EQ(GumboParser::normalizeHtml("<h2>x</h2>"), "<h2>x</h2>");
  EXPECT_EQ(GumboParser::normalizeHtml("<h3>x</h3>"), "<h3>x</h3>");
  EXPECT_EQ(GumboParser::normalizeHtml("<h4>x</h4>"), "<h4>x</h4>");
  EXPECT_EQ(GumboParser::normalizeHtml("<h5>x</h5>"), "<h5>x</h5>");
  EXPECT_EQ(GumboParser::normalizeHtml("<h6>x</h6>"), "<h6>x</h6>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<h1><strong>Bold Heading</strong></h1>\n\n"
                                 "<h1><em>Italic Heading</em></h1>\n\n"
                                 "<h1><u>Underline Heading</u></h1>\n\n"
                                 "<h1><s>Strikethrough Heading</s></h1>\n\n"
                                 "<h1>\n"
                                 "  <a href=\"https://example.com\">\n"
                                 "    Linked Heading\n"
                                 "  </a>\n"
                                 "</h1>\n\n"
                                 "<h1><code>Code Heading</code></h1>"),
      "<h1><b>Bold Heading</b></h1><h1><i>Italic Heading</i></h1>"
      "<h1><u>Underline Heading</u></h1><h1><s>Strikethrough Heading</s></h1>"
      "<h1><a href=\"https://example.com\">Linked Heading</a> </h1>"
      "<h1><code>Code Heading</code></h1>");

  // Alignment style attributes
  EXPECT_EQ(GumboParser::normalizeHtml("<p style=\"text-align: center\">x</p>"),
            "<p style=\"text-align: center\">x</p>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<h2 style=\"text-align: right\">x</h2>"),
      "<h2 style=\"text-align: right\">x</h2>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<blockquote style=\"text-align: justify\">x</blockquote>"),
            "<blockquote style=\"text-align: justify\"><p>x</p></blockquote>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ul><li style=\"text-align: center\">x</li></ul>"),
            "<ul><li style=\"text-align: center\">x</li></ul>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<div style=\"text-align: right\">x</div>"),
      "<p style=\"text-align: right\">x</p>");

  // Self-closing tags
  EXPECT_EQ(GumboParser::normalizeHtml("<br>"), "<br>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<img src=\"x\" width=\"100\" height=\"100\" />"),
            "<img src=\"x\" width=\"100\" height=\"100\" />");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<img src='x' width='100' height='100' />"),
      "<img src=\"x\" width=\"100\" height=\"100\" />");

  // Lists
  EXPECT_EQ(GumboParser::normalizeHtml("<ul><li>x</li></ul>"),
            "<ul><li>x</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml("<ol><li>x</li></ol>"),
            "<ol><li>x</li></ol>");

  // Checkbox lists
  EXPECT_EQ(
      GumboParser::normalizeHtml("<ul data-type='checkbox'><li>x</li></ul>"),
      "<ul data-type=\"checkbox\"><li>x</li></ul>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<ul data-type=\"checkbox\"><li>x</li></ul>"),
      "<ul data-type=\"checkbox\"><li>x</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ul data-type='checkbox'><li checked>x</li></ul>"),
            "<ul data-type=\"checkbox\"><li checked>x</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ul data-type=\"checkbox\"><li checked>x</li></ul>"),
            "<ul data-type=\"checkbox\"><li checked>x</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml("<ul data-type='checkboxList'><li "
                                       "data-checked='true'>x</li></ul>"),
            "<ul data-type=\"checkbox\"><li checked>x</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ul data-type='CheckboxList'><li checked='false'>x</li><li "
                "data-checked='false'>y</li></ul>"),
            "<ul data-type=\"checkbox\"><li>x</li><li>y</li></ul>");

  // Mentions
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<mention text='@John Doe' indicator='@' id='1'>@John Doe</mention>"),
      "<mention id=\"1\" text=\"@John Doe\" indicator=\"@\">@John "
      "Doe</mention>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<mention text=\"@John Doe\" indicator=\"@\" "
                                 "id=\"1\">@John Doe</mention>"),
      "<mention id=\"1\" text=\"@John Doe\" indicator=\"@\">@John "
      "Doe</mention>");

  // Link
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<a href=\"https://www.google.com\">Google</a>"),
            "<a href=\"https://www.google.com\">Google</a>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<a href='https://www.google.com'>Google</a>"),
      "<a href=\"https://www.google.com\">Google</a>");

  // Inline
  EXPECT_EQ(GumboParser::normalizeHtml("<code>x</code>"), "<code>x</code>");
  EXPECT_EQ(GumboParser::normalizeHtml("<s>x</s>"), "<s>x</s>");
  EXPECT_EQ(GumboParser::normalizeHtml("<u>x</u>"), "<u>x</u>");
  EXPECT_EQ(GumboParser::normalizeHtml("<i>x</i>"), "<i>x</i>");
  EXPECT_EQ(GumboParser::normalizeHtml("<b>x</b>"), "<b>x</b>");
}

TEST(GumboParserTest, InlineCodeDoesNotAbsorbAdjacentPunctuation) {
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<p>Text before <code>inline code</code>, and after.</p>"),
            "<p>Text before <code>inline code</code>, and after.</p>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<p>Text before <code>inline code</code>.</p>"),
            "<p>Text before <code>inline code</code>.</p>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<blockquote><p>Quote with <b>bold</b>, <code>inline "
                "code</code>, and <a href=\"https://example.com\">link "
                "text</a>.</p></blockquote>"),
            "<blockquote><p>Quote with <b>bold</b>, <code>inline code</code>, "
            "and <a href=\"https://example.com\">link "
            "text</a>.</p></blockquote>");
}

TEST(GumboParserTest, DivRemappings) {
  EXPECT_EQ(GumboParser::normalizeHtml("<div>x</div>"), "<p>x</p>");
  EXPECT_EQ(GumboParser::normalizeHtml("<div><p>x</p></div>"), "<p>x</p>");
  EXPECT_EQ(GumboParser::normalizeHtml("<div><p>x</p><p>y</p></div>"),
            "<p>x</p><p>y</p>");
  EXPECT_EQ(GumboParser::normalizeHtml("<div><p>x</p><p>y</p></div>"),
            "<p>x</p><p>y</p>");
  EXPECT_EQ(GumboParser::normalizeHtml("<div><span>x</span></div>"),
            "<p>x</p>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<div><div><span>x</span></div><span>y</span></div>"),
            "<p>x</p><p>y</p>");

  // Without whitespace
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<span>--</span><br><div><div><span>John<span> "
          "</span></span><b>Doe</b><div><u><i>Software</i></u><span> "
          "</span>Engineer</div></div></div>"),
      "<p>--</p><p>John <b>Doe</b></p><p><u><i>Software</i></u> Engineer</p>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<div><div><span>John<span> "
                "</span></span><b>Doe</b><div><u><i>Software</i></u><span> "
                "</span>Engineer</div></div></div>"),
            "<p>John <b>Doe</b></p><p><u><i>Software</i></u> Engineer</p>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='font-weight: "
                "700'>--</span><br><div><div><span>John<span> "
                "</span></span><b>Doe</b><div><u><i>Software</i></u><span> "
                "</span>Engineer</div></div></div>"),
            "<p><b>--</b></p><p>John <b>Doe</b></p><p><u><i>Software</i></u> "
            "Engineer</p>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='font-style: "
                "italic'>--</span><br><div><div><span>John<span> "
                "</span></span><b>Doe</b><div><u><i>Software</i></u><span> "
                "</span>Engineer</div></div></div>"),
            "<p><i>--</i></p><p>John <b>Doe</b></p><p><u><i>Software</i></u> "
            "Engineer</p>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<span style='font-style: italic; font-weight: "
                "bold'>--</span><br><div><div><span>John<span> "
                "</span></span><b>Doe</b><div><u><i>Software</i></u><span> "
                "</span>Engineer</div></div></div>"),
            "<p><b><i>--</i></b></p><p>John "
            "<b>Doe</b></p><p><u><i>Software</i></u> Engineer</p>");
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<span style='font-style: italic; font-weight: bold; "
          "text-decoration: underline'>--</span><br><div><div><span>John<span> "
          "</span></span><b>Doe</b><div><u><i>Software</i></u><span> "
          "</span>Engineer</div></div></div>"),
      "<p><b><i><u>--</u></i></b></p><p>John "
      "<b>Doe</b></p><p><u><i>Software</i></u> Engineer</p>");

  EXPECT_EQ(GumboParser::normalizeHtml(
                "<div><br>here's more!</div><div><br></div><img "
                "src=\"https://example.com/image.png\" alt=\"image.png\" "
                "width=\"336\" height=\"297\">"),
            "<br><p>here's more!</p><br><p><img "
            "src=\"https://example.com/image.png\" alt=\"image.png\" "
            "width=\"336\" height=\"297\" /></p>");

  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<div>what do you think of this "
          "craziness</div><span><blockquote><div><div><ul><li><b>another one "
          "</b>hello<div><br></div><div>hi</div></li></ul></div></div></"
          "blockquote></span>"),
      "<p>what do you think of this "
      "craziness</p><blockquote><ul><li><b>another "
      "one </b>hello<br><p>hi</p></li></ul></blockquote>");
}

TEST(GumboParserTest, ListFlattening) {
  EXPECT_EQ(
      GumboParser::normalizeHtml("<ul><ol><li>x</li><li>y</li></ol></ul>"),
      "<ul><li>x</li><li>y</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ul><li>x</li><ol><li>y</li><li>z</li></ol></ul>"),
            "<ul><li>x</li><li>y</li><li>z</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ul><ol><li>x</li><li>y</li></ol><li>z</li></ul>"),
            "<ul><li>x</li><li>y</li><li>z</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ol><li>x</li><ul><li>y</li><li>z</li></ul></ol>"),
            "<ol><li>x</li><li>y</li><li>z</li></ol>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ol><ul><li>x</li><li>y</li></ul><li>z</li></ol>"),
            "<ol><li>x</li><li>y</li><li>z</li></ol>");
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<ol><ul "
          "data-type='checkbox'><li>x</li><li>y</li></ul><li>z</li></ol>"),
      "<ol><li>x</li><li>y</li><li>z</li></ol>");
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<ul "
          "data-type='checkbox'><ol><li>x</li><li>y</li></ol><li>z</li></ul>"),
      "<ul data-type=\"checkbox\"><li>x</li><li>y</li><li>z</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ul><li>x</li><ol><li>y</li><ul><li>z</li></ul></ol></ul>"),
            "<ul><li>x</li><li>y</li><li>z</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ul><li>x</li><ol><li>y</li><ul "
                "data-type='checkbox'><li>z</li></ul></ol></ul>"),
            "<ul><li>x</li><li>y</li><li>z</li></ul>");
  EXPECT_EQ(
      GumboParser::normalizeHtml("<ul "
                                 "data-type='checkbox'><li>x</li><ol><li>y</"
                                 "li><ul><li>z</li></ul></ol></ul>"),
      "<ul data-type=\"checkbox\"><li>x</li><li>y</li><li>z</li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ul><li><b>another one </b>hi "
                "kacper,<div><br></div><div>hi</div></li></ul>"),
            "<ul><li><b>another one </b>hi kacper,<br><p>hi</p></li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ol><li>parent<ul data-type='checkbox'><li "
                "checked>done</li><li>todo</li></ul></li></ol>"),
            "<ol><li>parent<ul data-type=\"checkbox\"><li "
            "checked>done</li><li>todo</li></ul></li></ol>");
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<ul><li>parent<ol><li>first</li><li>second</li></ol></li></ul>"),
      "<ul><li>parent<ol><li>first</li><li>second</li></ol></li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ul><li>Parent<ol><li>Number</li><ul><li>Bullet</li></ul></"
                "ol></li></ul>"),
            "<ul><li>Parent<ol><li>Number</li><li>Bullet</li></ol></li></ul>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<ol><li>Parent<ul data-type='checkbox'><li checked>Done</li>"
                "</ul></li><li>Next</li></ol>"),
            "<ol><li>Parent<ul data-type=\"checkbox\"><li "
            "checked>Done</li></ul></li><li>Next</li></ol>");
  EXPECT_EQ(GumboParser::normalizeHtml("<ol><ol><ol><li>Deep</li></ol></ol></"
                                       "ol>"),
            "<ol><li>Deep</li></ol>");
}

TEST(GumboParserTest, NestedBlockquotesPreserveBlockContent) {
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<blockquote><p>Outer</p><blockquote><p>Inner</p><ul><li>Bullet</"
          "li></ul></blockquote></blockquote>"),
      "<blockquote><p>Outer</p><blockquote><p>Inner</p><ul><li>Bullet</li></"
      "ul></blockquote></blockquote>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<blockquote><pre>Code block inside quote\nLine 2</pre><ul><li>"
                "Item</li></ul></blockquote>"),
            "<blockquote><codeblock><p>Code block inside quote\nLine 2</p></"
            "codeblock><ul><li>Item</li></ul></blockquote>");
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<blockquote><p>Quote image below:</p><img src=\"x\" "
                "width=\"64\" height=\"64\" /></blockquote><ul><li>Root</li>"
                "</ul>"),
            "<blockquote><p>Quote image below:</p><p><img src=\"x\" "
            "width=\"64\" height=\"64\" /></p></blockquote><ul><li>Root</li>"
            "</ul>");
}

TEST(GumboParserTest, NestedMarkerOrderingStructureIsPreserved) {
  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<blockquote><p>Outer quote</p><ol><li>Ordered item<blockquote><p>"
          "Quote inside ordered item</p></blockquote></li><li>Ordered item "
          "with "
          "unordered child<ul><li>Unordered child<blockquote><p>Quote inside "
          "unordered child</p></blockquote></li></ul></li></ol><ul><li>Bullet "
          "item<blockquote><p>Quote inside bullet item</p></blockquote></li></"
          "ul></blockquote>"),
      "<blockquote><p>Outer quote</p><ol><li>Ordered item<blockquote><p>Quote "
      "inside ordered item</p></blockquote></li><li>Ordered item with "
      "unordered "
      "child<ul><li>Unordered child<blockquote><p>Quote inside unordered "
      "child</"
      "p></blockquote></li></ul></li></ol><ul><li>Bullet item<blockquote><p>"
      "Quote inside bullet item</p></blockquote></li></ul></blockquote>");

  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<ul><li>List item with checkbox children<ul "
          "data-type='checkbox'><li "
          "checked>Checked checkbox<ol><li>Ordered child</li><li>Ordered child "
          "with quote<blockquote><p>Quote inside ordered child</p></blockquote>"
          "</li></ol></li><li>Unchecked checkbox<ul><li>Unordered "
          "child</li><li>"
          "Unordered child with quote<blockquote><p>Quote inside unordered "
          "child</p></blockquote></li></ul></li></ul></li></ul>"),
      "<ul><li>List item with checkbox children<ul data-type=\"checkbox\"><li "
      "checked>Checked checkbox<ol><li>Ordered child</li><li>Ordered child "
      "with "
      "quote<blockquote><p>Quote inside ordered child</p></blockquote></li></"
      "ol></li><li>Unchecked checkbox<ul><li>Unordered child</li><li>Unordered "
      "child with quote<blockquote><p>Quote inside unordered child</p></"
      "blockquote></li></ul></li></ul></li></ul>");

  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<ul><li><blockquote><p>Quote first in bullet</p></blockquote></li></"
          "ul><ol><li><blockquote><p>Quote first in number</p></blockquote></"
          "li></ol><ul data-type='checkbox'><li checked><blockquote><p>Quote "
          "first in checked checkbox</p></blockquote></li><li><blockquote><p>"
          "Quote first in unchecked checkbox</p></blockquote></li></ul>"),
      "<ul><li><blockquote><p>Quote first in bullet</p></blockquote></li></"
      "ul><ol><li><blockquote><p>Quote first in number</p></blockquote></li></"
      "ol><ul data-type=\"checkbox\"><li checked><blockquote><p>Quote first in "
      "checked checkbox</p></blockquote></li><li><blockquote><p>Quote first in "
      "unchecked checkbox</p></blockquote></li></ul>");

  EXPECT_EQ(
      GumboParser::normalizeHtml(
          "<blockquote><ul data-type='checkbox'><li checked><blockquote><p>"
          "Quote first in checked checkbox inside "
          "quote</p></blockquote></li><li>"
          "<blockquote><p>Quote first in unchecked checkbox inside quote</p></"
          "blockquote></li></ul><ul><li><blockquote><p>Quote first in bullet "
          "inside quote</p></blockquote></li></ul><ol><li><blockquote><p>Quote "
          "first in number inside "
          "quote</p></blockquote></li></ol></blockquote>"),
      "<blockquote><ul data-type=\"checkbox\"><li checked><blockquote><p>Quote "
      "first in checked checkbox inside quote</p></blockquote></li><li><"
      "blockquote><p>Quote first in unchecked checkbox inside quote</p></"
      "blockquote></li></ul><ul><li><blockquote><p>Quote first in bullet "
      "inside "
      "quote</p></blockquote></li></ul><ol><li><blockquote><p>Quote first in "
      "number inside quote</p></blockquote></li></ol></blockquote>");
}

TEST(GumboParserTest, BrRemappings) {
  EXPECT_EQ(GumboParser::normalizeHtml(
                "<p><b>Asdasdasd</b></p><br><br><p>Sent with<span> </span><a "
                "href='https://google.com'>Net</a></p>"),
            "<p><b>Asdasdasd</b></p><br><br><p>Sent with <a "
            "href=\"https://google.com\">Net</a></p>");
}
