package com.swmansion.enriched.common.parser;

import android.text.Editable;
import android.text.Layout;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.TextUtils;
import android.text.style.AlignmentSpan;
import android.text.style.ParagraphStyle;
import com.swmansion.enriched.common.EnrichedConstants;
import com.swmansion.enriched.common.spans.EnrichedBlockQuoteSpan;
import com.swmansion.enriched.common.spans.EnrichedBoldSpan;
import com.swmansion.enriched.common.spans.EnrichedCheckboxListSpan;
import com.swmansion.enriched.common.spans.EnrichedCodeBlockSpan;
import com.swmansion.enriched.common.spans.EnrichedH1Span;
import com.swmansion.enriched.common.spans.EnrichedH2Span;
import com.swmansion.enriched.common.spans.EnrichedH3Span;
import com.swmansion.enriched.common.spans.EnrichedH4Span;
import com.swmansion.enriched.common.spans.EnrichedH5Span;
import com.swmansion.enriched.common.spans.EnrichedH6Span;
import com.swmansion.enriched.common.spans.EnrichedImageSpan;
import com.swmansion.enriched.common.spans.EnrichedInlineCodeSpan;
import com.swmansion.enriched.common.spans.EnrichedItalicSpan;
import com.swmansion.enriched.common.spans.EnrichedLinkSpan;
import com.swmansion.enriched.common.spans.EnrichedMentionSpan;
import com.swmansion.enriched.common.spans.EnrichedOrderedListSpan;
import com.swmansion.enriched.common.spans.EnrichedStrikeThroughSpan;
import com.swmansion.enriched.common.spans.EnrichedUnderlineSpan;
import com.swmansion.enriched.common.spans.EnrichedUnorderedListSpan;
import com.swmansion.enriched.common.spans.interfaces.EnrichedBlockSpan;
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan;
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan;
import com.swmansion.enriched.common.spans.interfaces.EnrichedParagraphSpan;
import com.swmansion.enriched.common.spans.interfaces.EnrichedZeroWidthSpaceSpan;
import java.io.IOException;
import java.io.StringReader;
import java.util.ArrayDeque;
import java.util.HashMap;
import java.util.Map;
import org.ccil.cowan.tagsoup.HTMLSchema;
import org.ccil.cowan.tagsoup.Parser;
import org.xml.sax.Attributes;
import org.xml.sax.ContentHandler;
import org.xml.sax.InputSource;
import org.xml.sax.Locator;
import org.xml.sax.SAXException;
import org.xml.sax.SAXNotRecognizedException;
import org.xml.sax.SAXNotSupportedException;
import org.xml.sax.XMLReader;

/**
 * Most of the code in this file is copied from the Android source code and adjusted to our needs.
 * For the reference see <a
 * href="https://android.googlesource.com/platform/frameworks/base/+/refs/heads/master/core/java/android/text/Html.java">docs</a>
 */
public class EnrichedParser {
  /** Retrieves images for HTML &lt;img&gt; tags. */
  private EnrichedParser() {}

  /**
   * Lazy initialization holder for HTML parser. This class will a) be preloaded by the zygote, or
   * b) not loaded until absolutely necessary.
   */
  private static class HtmlParser {
    private static final HTMLSchema schema = new HTMLSchema();
  }

  public static <T> Spanned fromHtml(String source, T style, EnrichedSpanFactory<T> spanFactory) {
    Parser parser = new Parser();
    try {
      parser.setProperty(Parser.schemaProperty, HtmlParser.schema);
    } catch (SAXNotRecognizedException | SAXNotSupportedException e) {
      // Should not happen.
      throw new RuntimeException(e);
    }
    HtmlToSpannedConverter converter =
        new HtmlToSpannedConverter(source, style, parser, spanFactory);
    return converter.convert();
  }

  public static String toHtml(Spanned text) {
    StringBuilder out = new StringBuilder();
    withinHtml(out, text);
    String outString = out.toString();

    // Codeblocks and blockquotes appends a newline character by default, so we have to remove it
    String normalizedCodeBlock = outString.replaceAll("</codeblock>\\n<br>", "</codeblock>");
    String normalizedBlockQuote =
        normalizedCodeBlock.replaceAll("</blockquote>\\n<br>", "</blockquote>");

    // replace empty <p></p> into <br> in the very end
    String normalizedHtml = normalizedBlockQuote.replaceAll("<p></p>", "<br>");

    return "<html>\n" + normalizedHtml + "</html>";
  }

  public static String toHtmlWithDefault(CharSequence text) {
    if (text instanceof Spanned) {
      return toHtml((Spanned) text);
    }
    return "<html>\n<p></p>\n</html>";
  }

  /** Returns an HTML escaped representation of the given plain text. */
  public static String escapeHtml(CharSequence text) {
    StringBuilder out = new StringBuilder();
    withinStyle(out, text, 0, text.length());
    return out.toString();
  }

  private static void withinHtml(StringBuilder out, Spanned text) {
    withinDiv(out, text, 0, text.length());
  }

  private static void withinDiv(StringBuilder out, Spanned text, int start, int end) {
    int next;
    for (int i = start; i < end; i = next) {
      next = text.nextSpanTransition(i, end, EnrichedBlockSpan.class);
      EnrichedBlockSpan[] blocks = text.getSpans(i, next, EnrichedBlockSpan.class);
      String tag = "unknown";
      if (blocks.length > 0) {
        tag = blocks[0] instanceof EnrichedCodeBlockSpan ? "codeblock" : "blockquote";
      }

      // Each block appends a newline by default.
      // If we set up a new block, we have to remove the last  character.
      if (out.length() >= 5 && out.substring(out.length() - 5).equals("<br>\n")) {
        out.replace(out.length() - 5, out.length(), "");
      }

      for (EnrichedBlockSpan ignored : blocks) {
        out.append("<").append(tag).append(getAlignmentStyle(text, i, next)).append(">\n");
      }
      withinBlock(out, text, i, next);
      for (EnrichedBlockSpan ignored : blocks) {
        out.append("</").append(tag).append(">\n");
      }
    }
  }

  private static String getBlockTag(EnrichedParagraphSpan[] spans) {
    EnrichedListSpan deepestList = null;

    for (EnrichedParagraphSpan span : spans) {
      if (span instanceof EnrichedListSpan) {
        EnrichedListSpan listSpan = (EnrichedListSpan) span;
        if (deepestList == null || listSpan.getLevel() >= deepestList.getLevel()) {
          deepestList = listSpan;
        }
      }
    }

    if (deepestList instanceof EnrichedUnorderedListSpan) {
      return "ul";
    } else if (deepestList instanceof EnrichedOrderedListSpan) {
      return "ol";
    } else if (deepestList instanceof EnrichedCheckboxListSpan) {
      return "ul data-type=\"checkbox\"";
    }

    for (EnrichedParagraphSpan span : spans) {
      if (span instanceof EnrichedH1Span) {
        return "h1";
      } else if (span instanceof EnrichedH2Span) {
        return "h2";
      } else if (span instanceof EnrichedH3Span) {
        return "h3";
      } else if (span instanceof EnrichedH4Span) {
        return "h4";
      } else if (span instanceof EnrichedH5Span) {
        return "h5";
      } else if (span instanceof EnrichedH6Span) {
        return "h6";
      }
    }

    return "p";
  }

  private static String getAlignmentStyle(Spanned text, int start, int end) {
    AlignmentSpan[] alignmentSpans = text.getSpans(start, end, AlignmentSpan.class);
    if (alignmentSpans.length == 0) {
      return "";
    }

    Layout.Alignment alignment = alignmentSpans[alignmentSpans.length - 1].getAlignment();
    if (alignment == Layout.Alignment.ALIGN_CENTER) {
      return " style=\"text-align: center\"";
    }
    if (alignment == Layout.Alignment.ALIGN_OPPOSITE) {
      return " style=\"text-align: right\"";
    }
    if (alignment == Layout.Alignment.ALIGN_NORMAL) {
      return " style=\"text-align: left\"";
    }

    return "";
  }

  private static void withinBlock(StringBuilder out, Spanned text, int start, int end) {
    boolean isInUlList = false;
    boolean isInOlList = false;
    boolean isInCheckboxList = false;

    int next;
    for (int i = start; i <= end; i = next) {
      next = TextUtils.indexOf(text, '\n', i, end);
      if (next < 0) {
        next = end;
      }
      if (next == i) {
        if (isInUlList) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInUlList = false;
          out.append("</ul>\n");
        } else if (isInOlList) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInOlList = false;
          out.append("</ol>\n");
        } else if (isInCheckboxList) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInCheckboxList = false;
          out.append("</ul>\n");
        }
        out.append("<br>\n");
      } else {
        EnrichedParagraphSpan[] paragraphStyles =
            text.getSpans(i, next, EnrichedParagraphSpan.class);
        String tag = getBlockTag(paragraphStyles);
        boolean isUlListItem = tag.equals("ul");
        boolean isOlListItem = tag.equals("ol");
        boolean isCheckboxListItem = tag.equals("ul data-type=\"checkbox\"");

        if (isInUlList && !isUlListItem) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInUlList = false;
          out.append("</ul>\n");
        } else if (isInOlList && !isOlListItem) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInOlList = false;
          out.append("</ol>\n");
        } else if (isInCheckboxList && !isCheckboxListItem) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInCheckboxList = false;
          out.append("</ul>\n");
        }

        if (isUlListItem && !isInUlList) {
          // Current paragraph is the first item in a list
          isInUlList = true;
          out.append("<ul").append(">\n");
        } else if (isOlListItem && !isInOlList) {
          // Current paragraph is the first item in a list
          isInOlList = true;
          out.append("<ol").append(">\n");
        } else if (isCheckboxListItem && !isInCheckboxList) {
          // Current paragraph is the first item in a list
          isInCheckboxList = true;
          out.append("<ul data-type=\"checkbox\">\n");
        }

        boolean isList = isUlListItem || isOlListItem || isCheckboxListItem;
        String tagType = isList ? "li" : tag;

        out.append("<");
        out.append(tagType);

        if (isCheckboxListItem) {
          EnrichedCheckboxListSpan[] checkboxSpans =
              text.getSpans(i, next, EnrichedCheckboxListSpan.class);
          if (checkboxSpans.length > 0) {
            boolean isChecked = checkboxSpans[0].isChecked();
            if (isChecked) out.append(" checked");
          }
        }

        out.append(getAlignmentStyle(text, i, next));
        out.append(">");
        withinParagraph(out, text, i, next);
        out.append("</");
        out.append(tagType);
        out.append(">\n");
        if (next == end && isInUlList) {
          isInUlList = false;
          out.append("</ul>\n");
        } else if (next == end && isInOlList) {
          isInOlList = false;
          out.append("</ol>\n");
        } else if (next == end && isInCheckboxList) {
          isInCheckboxList = false;
          out.append("</ul>\n");
        }
      }
      next++;
    }
  }

  private static void withinParagraph(StringBuilder out, Spanned text, int start, int end) {
    int next;
    for (int i = start; i < end; i = next) {
      next = text.nextSpanTransition(i, end, EnrichedInlineSpan.class);
      EnrichedInlineSpan[] style = text.getSpans(i, next, EnrichedInlineSpan.class);
      for (int j = 0; j < style.length; j++) {
        if (style[j] instanceof EnrichedBoldSpan) {
          out.append("<b>");
        }
        if (style[j] instanceof EnrichedItalicSpan) {
          out.append("<i>");
        }
        if (style[j] instanceof EnrichedUnderlineSpan) {
          out.append("<u>");
        }
        if (style[j] instanceof EnrichedInlineCodeSpan) {
          out.append("<code>");
        }
        if (style[j] instanceof EnrichedStrikeThroughSpan) {
          out.append("<s>");
        }
        if (style[j] instanceof EnrichedLinkSpan) {
          out.append("<a href=\"");
          out.append(((EnrichedLinkSpan) style[j]).getUrl());
          out.append("\">");
        }
        if (style[j] instanceof EnrichedMentionSpan) {
          out.append("<mention text=\"");
          out.append(((EnrichedMentionSpan) style[j]).getText());
          out.append("\"");

          out.append(" indicator=\"");
          out.append(((EnrichedMentionSpan) style[j]).getIndicator());
          out.append("\"");

          Map<String, String> attributes = ((EnrichedMentionSpan) style[j]).getAttributes();
          for (Map.Entry<String, String> entry : attributes.entrySet()) {
            out.append(" ");
            out.append(entry.getKey());
            out.append("=\"");
            out.append(entry.getValue());
            out.append("\"");
          }

          out.append(">");
        }
        if (style[j] instanceof EnrichedImageSpan) {
          out.append("<img src=\"");
          out.append(((EnrichedImageSpan) style[j]).getSource());
          out.append("\"");

          out.append(" width=\"");
          out.append(((EnrichedImageSpan) style[j]).getWidth());
          out.append("\"");

          out.append(" height=\"");
          out.append(((EnrichedImageSpan) style[j]).getHeight());

          out.append("\"/>");
          // Don't output the placeholder character underlying the image.
          i = next;
        }
      }
      withinStyle(out, text, i, next);
      for (int j = style.length - 1; j >= 0; j--) {
        if (style[j] instanceof EnrichedLinkSpan) {
          out.append("</a>");
        }
        if (style[j] instanceof EnrichedMentionSpan) {
          out.append("</mention>");
        }
        if (style[j] instanceof EnrichedStrikeThroughSpan) {
          out.append("</s>");
        }
        if (style[j] instanceof EnrichedUnderlineSpan) {
          out.append("</u>");
        }
        if (style[j] instanceof EnrichedInlineCodeSpan) {
          out.append("</code>");
        }
        if (style[j] instanceof EnrichedBoldSpan) {
          out.append("</b>");
        }
        if (style[j] instanceof EnrichedItalicSpan) {
          out.append("</i>");
        }
      }
    }
  }

  private static void withinStyle(StringBuilder out, CharSequence text, int start, int end) {
    for (int i = start; i < end; i++) {
      char c = text.charAt(i);
      if (c == EnrichedConstants.ZWS) {
        // Do not output zero-width space characters.
        continue;
      } else if (c == '<') {
        out.append("&lt;");
      } else if (c == '>') {
        out.append("&gt;");
      } else if (c == '&') {
        out.append("&amp;");
      } else if (c >= 0xD800 && c <= 0xDFFF) {
        if (c < 0xDC00 && i + 1 < end) {
          char d = text.charAt(i + 1);
          if (d >= 0xDC00 && d <= 0xDFFF) {
            i++;
            int codepoint = 0x010000 | (int) c - 0xD800 << 10 | (int) d - 0xDC00;
            out.append("&#").append(codepoint).append(";");
          }
        }
      } else if (c > 0x7E || c < ' ') {
        out.append("&#").append((int) c).append(";");
      } else if (c == ' ') {
        while (i + 1 < end && text.charAt(i + 1) == ' ') {
          out.append("&nbsp;");
          i++;
        }
        out.append(' ');
      } else {
        out.append(c);
      }
    }
  }
}

class HtmlToSpannedConverter<T> implements ContentHandler {
  private final EnrichedSpanFactory<T> mSpanFactory;
  private final T mStyle;
  private final String mSource;
  private final XMLReader mReader;
  private final SpannableStringBuilder mSpannableStringBuilder;
  private final ArrayDeque<ListContext> mListStack = new ArrayDeque<>();
  private static Boolean isEmptyTag = false;
  private int mCodeBlockDepth = 0;

  public HtmlToSpannedConverter(
      String source, T style, Parser parser, EnrichedSpanFactory<T> spanFactory) {
    mStyle = style;
    mSource = source;
    mSpannableStringBuilder = new SpannableStringBuilder();
    mReader = parser;
    mSpanFactory = spanFactory;
  }

  public Spanned convert() {
    mReader.setContentHandler(this);
    try {
      mReader.parse(new InputSource(new StringReader(mSource)));
    } catch (IOException e) {
      // We are reading from a string. There should not be IO problems.
      throw new RuntimeException(e);
    } catch (SAXException e) {
      // TagSoup doesn't throw parse exceptions.
      throw new RuntimeException(e);
    }
    // Fix flags and range for paragraph-type markup.
    Object[] obj =
        mSpannableStringBuilder.getSpans(0, mSpannableStringBuilder.length(), ParagraphStyle.class);
    for (int i = 0; i < obj.length; i++) {
      int start = mSpannableStringBuilder.getSpanStart(obj[i]);
      int end = mSpannableStringBuilder.getSpanEnd(obj[i]);
      // If the last line of the range is blank, back off by one.
      if (end - 2 >= 0) {
        if (mSpannableStringBuilder.charAt(end - 1) == '\n'
            && mSpannableStringBuilder.charAt(end - 2) == '\n') {
          end--;
        }
      }
      if (end == start) {
        mSpannableStringBuilder.removeSpan(obj[i]);
      } else {
        // TODO: verify if Spannable.SPAN_EXCLUSIVE_EXCLUSIVE does not break anything.
        // Previously it was SPAN_PARAGRAPH. I've changed that in order to fix ranges for list
        // items.
        int flags =
            obj[i] instanceof EnrichedBlockSpan || obj[i] instanceof AlignmentSpan
                ? Spannable.SPAN_INCLUSIVE_EXCLUSIVE
                : Spannable.SPAN_EXCLUSIVE_EXCLUSIVE;
        mSpannableStringBuilder.setSpan(obj[i], start, end, getSpanFlags(obj[i], flags));
      }
    }

    trimParentListSpansFromNestedParagraphs();

    // Assign zero-width space character to the proper spans.
    EnrichedZeroWidthSpaceSpan[] zeroWidthSpaceSpans =
        mSpannableStringBuilder.getSpans(
            0, mSpannableStringBuilder.length(), EnrichedZeroWidthSpaceSpan.class);
    for (EnrichedZeroWidthSpaceSpan zeroWidthSpaceSpan : zeroWidthSpaceSpans) {
      int start = mSpannableStringBuilder.getSpanStart(zeroWidthSpaceSpan);
      int end = mSpannableStringBuilder.getSpanEnd(zeroWidthSpaceSpan);

      if (mSpannableStringBuilder.charAt(start) != EnrichedConstants.ZWS) {
        // Insert zero-width space character at the start if it's not already present.
        mSpannableStringBuilder.insert(start, EnrichedConstants.ZWS_STRING);
        end++; // Adjust end position due to insertion.
      }

      mSpannableStringBuilder.removeSpan(zeroWidthSpaceSpan);
      mSpannableStringBuilder.setSpan(
          zeroWidthSpaceSpan, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
    }

    trimParentListSpansFromNestedParagraphs();

    return mSpannableStringBuilder;
  }

  private void trimParentListSpansFromNestedParagraphs() {
    int textLength = mSpannableStringBuilder.length();
    int paragraphStart = 0;

    while (paragraphStart < textLength) {
      int paragraphEnd = TextUtils.indexOf(mSpannableStringBuilder, '\n', paragraphStart);
      if (paragraphEnd < 0) {
        paragraphEnd = textLength;
      }

      trimParentListSpansFromParagraph(paragraphStart, paragraphEnd);

      if (paragraphEnd >= textLength) {
        break;
      }
      paragraphStart = paragraphEnd + 1;
    }
  }

  private void trimParentListSpansFromParagraph(int paragraphStart, int paragraphEnd) {
    if (paragraphStart >= paragraphEnd) {
      return;
    }

    EnrichedListSpan[] listSpans =
        mSpannableStringBuilder.getSpans(paragraphStart, paragraphEnd, EnrichedListSpan.class);
    if (listSpans.length <= 1) {
      return;
    }

    int deepestLevel = 0;
    for (EnrichedListSpan span : listSpans) {
      deepestLevel = Math.max(deepestLevel, span.getLevel());
    }

    for (EnrichedListSpan span : listSpans) {
      if (span.getLevel() < deepestLevel) {
        trimListSpanFromRange(span, paragraphStart, paragraphEnd);
      }
    }
  }

  private void trimListSpanFromRange(EnrichedListSpan span, int rangeStart, int rangeEnd) {
    int spanStart = mSpannableStringBuilder.getSpanStart(span);
    int spanEnd = mSpannableStringBuilder.getSpanEnd(span);
    int flags = mSpannableStringBuilder.getSpanFlags(span);

    if (spanStart < 0 || spanEnd < 0 || spanStart >= spanEnd) {
      return;
    }

    int trimStart = Math.max(spanStart, rangeStart);
    int trimEnd = Math.min(spanEnd, rangeEnd);
    if (trimStart >= trimEnd) {
      return;
    }

    mSpannableStringBuilder.removeSpan(span);

    int beforeEnd = trimStart;
    while (beforeEnd > spanStart && mSpannableStringBuilder.charAt(beforeEnd - 1) == '\n') {
      beforeEnd--;
    }

    int afterStart = trimEnd;
    while (afterStart < spanEnd && mSpannableStringBuilder.charAt(afterStart) == '\n') {
      afterStart++;
    }

    if (spanStart < beforeEnd) {
      mSpannableStringBuilder.setSpan(copyListSpan(span), spanStart, beforeEnd, flags);
    }
    if (afterStart < spanEnd) {
      mSpannableStringBuilder.setSpan(copyListSpan(span), afterStart, spanEnd, flags);
    }
  }

  private EnrichedListSpan copyListSpan(EnrichedListSpan span) {
    EnrichedListSpan copy;

    if (span instanceof EnrichedOrderedListSpan) {
      copy =
          mSpanFactory.createOrderedListSpan(((EnrichedOrderedListSpan) span).getIndex(), mStyle);
    } else if (span instanceof EnrichedCheckboxListSpan) {
      copy =
          mSpanFactory.createCheckboxListSpan(
              ((EnrichedCheckboxListSpan) span).isChecked(), mStyle);
    } else {
      copy = mSpanFactory.createUnorderedListSpan(mStyle);
    }

    copy.setLevel(span.getLevel());
    return copy;
  }

  private void handleStartTag(String tag, Attributes attributes) {
    if (tag.equalsIgnoreCase("br")) {
      // We don't need to handle this. TagSoup will ensure that there's a </br> for each <br>
      // so we can safely emit the linebreaks when we handle the close tag.
    } else if (tag.equalsIgnoreCase("p")) {
      isEmptyTag = true;
      startBlockElement(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("ul")) {
      String dataType = attributes.getValue("", "data-type");
      mListStack.addLast(
          new ListContext("checkbox".equalsIgnoreCase(dataType) ? "checked" : "unordered"));
      startBlockElement(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("ol")) {
      mListStack.addLast(new ListContext("ordered"));
      startBlockElement(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("li")) {
      isEmptyTag = true;
      startLi(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("b")) {
      start(mSpannableStringBuilder, new Bold());
    } else if (tag.equalsIgnoreCase("i")) {
      start(mSpannableStringBuilder, new Italic());
    } else if (tag.equalsIgnoreCase("blockquote")) {
      isEmptyTag = true;
      startBlockquote(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("codeblock")) {
      isEmptyTag = true;
      mCodeBlockDepth++;
      startCodeBlock(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("a")) {
      startA(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("u")) {
      start(mSpannableStringBuilder, new Underline());
    } else if (tag.equalsIgnoreCase("s")) {
      start(mSpannableStringBuilder, new Strikethrough());
    } else if (tag.equalsIgnoreCase("strike")) {
      start(mSpannableStringBuilder, new Strikethrough());
    } else if (tag.equalsIgnoreCase("h1")) {
      startHeading(mSpannableStringBuilder, 1, attributes);
    } else if (tag.equalsIgnoreCase("h2")) {
      startHeading(mSpannableStringBuilder, 2, attributes);
    } else if (tag.equalsIgnoreCase("h3")) {
      startHeading(mSpannableStringBuilder, 3, attributes);
    } else if (tag.equalsIgnoreCase("h4")) {
      startHeading(mSpannableStringBuilder, 4, attributes);
    } else if (tag.equalsIgnoreCase("h5")) {
      startHeading(mSpannableStringBuilder, 5, attributes);
    } else if (tag.equalsIgnoreCase("h6")) {
      startHeading(mSpannableStringBuilder, 6, attributes);
    } else if (tag.equalsIgnoreCase("img")) {
      // Image content means the current tag is not empty (e.g. <li><img .../></li>).
      isEmptyTag = false;
      startImg(mSpannableStringBuilder, attributes, mSpanFactory);
    } else if (tag.equalsIgnoreCase("code")) {
      start(mSpannableStringBuilder, new Code());
    } else if (tag.equalsIgnoreCase("mention")) {
      startMention(mSpannableStringBuilder, attributes);
    }
  }

  private void handleEndTag(String tag) {
    if (tag.equalsIgnoreCase("br")) {
      handleBr(mSpannableStringBuilder);
    } else if (tag.equalsIgnoreCase("p")) {
      endBlockElement(mSpannableStringBuilder);
    } else if (tag.equalsIgnoreCase("ul")) {
      endBlockElement(mSpannableStringBuilder);
      if (!mListStack.isEmpty()) {
        mListStack.removeLast();
      }
    } else if (tag.equalsIgnoreCase("ol")) {
      endBlockElement(mSpannableStringBuilder);
      if (!mListStack.isEmpty()) {
        mListStack.removeLast();
      }
    } else if (tag.equalsIgnoreCase("li")) {
      endLi(mSpannableStringBuilder, mStyle, mSpanFactory);
    } else if (tag.equalsIgnoreCase("b")) {
      end(mSpannableStringBuilder, Bold.class, mSpanFactory.createBoldSpan(mStyle));
    } else if (tag.equalsIgnoreCase("i")) {
      end(mSpannableStringBuilder, Italic.class, mSpanFactory.createItalicSpan(mStyle));
    } else if (tag.equalsIgnoreCase("blockquote")) {
      endBlockquote(mSpannableStringBuilder, mStyle, mSpanFactory);
    } else if (tag.equalsIgnoreCase("codeblock")) {
      endCodeBlock(mSpannableStringBuilder, mStyle, mSpanFactory);
      if (mCodeBlockDepth > 0) {
        mCodeBlockDepth--;
      }
    } else if (tag.equalsIgnoreCase("a")) {
      endA(mSpannableStringBuilder, mStyle, mSpanFactory);
    } else if (tag.equalsIgnoreCase("u")) {
      end(mSpannableStringBuilder, Underline.class, mSpanFactory.createUnderlineSpan(mStyle));
    } else if (tag.equalsIgnoreCase("s")) {
      end(
          mSpannableStringBuilder,
          Strikethrough.class,
          mSpanFactory.createStrikeThroughSpan(mStyle));
    } else if (tag.equalsIgnoreCase("h1")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 1);
    } else if (tag.equalsIgnoreCase("h2")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 2);
    } else if (tag.equalsIgnoreCase("h3")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 3);
    } else if (tag.equalsIgnoreCase("h4")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 4);
    } else if (tag.equalsIgnoreCase("h5")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 5);
    } else if (tag.equalsIgnoreCase("h6")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 6);
    } else if (tag.equalsIgnoreCase("code")) {
      end(mSpannableStringBuilder, Code.class, mSpanFactory.createInlineCodeSpan(mStyle));
    } else if (tag.equalsIgnoreCase("mention")) {
      endMention(mSpannableStringBuilder, mStyle, mSpanFactory);
    }
  }

  private static void appendNewlines(Editable text, int minNewline) {
    final int len = text.length();
    if (len == 0) {
      return;
    }
    int existingNewlines = 0;
    for (int i = len - 1; i >= 0 && text.charAt(i) == '\n'; i--) {
      existingNewlines++;
    }
    for (int j = existingNewlines; j < minNewline; j++) {
      text.append("\n");
    }
  }

  private static void startBlockElement(Editable text) {
    startBlockElement(text, null);
  }

  private static void startBlockElement(Editable text, Attributes attributes) {
    appendNewlines(text, 1);
    start(text, new Newline(1));
    Layout.Alignment alignment = getAlignmentFromAttributes(attributes);
    if (alignment != null) {
      start(text, new Alignment(alignment));
    }
  }

  private static Layout.Alignment getAlignmentFromAttributes(Attributes attributes) {
    if (attributes == null) return null;

    String style = attributes.getValue("", "style");
    if (style == null) return null;

    String[] declarations = style.split(";");
    for (String declaration : declarations) {
      String[] parts = declaration.split(":", 2);
      if (parts.length != 2 || !parts[0].trim().equalsIgnoreCase("text-align")) {
        continue;
      }

      String value = parts[1].trim().toLowerCase();
      if (value.startsWith("center")) {
        return Layout.Alignment.ALIGN_CENTER;
      }
      if (value.startsWith("right")) {
        return Layout.Alignment.ALIGN_OPPOSITE;
      }
      if (value.startsWith("left") || value.startsWith("justify")) {
        return Layout.Alignment.ALIGN_NORMAL;
      }
    }

    return null;
  }

  private static boolean isTruthyAttribute(String value) {
    if (value == null) return false;
    if (value.isEmpty()) return true;

    return value.equalsIgnoreCase("true")
        || value.equalsIgnoreCase("1")
        || value.equalsIgnoreCase("yes")
        || value.equalsIgnoreCase("checked");
  }

  private static void endBlockElement(Editable text) {
    Newline n = getLast(text, Newline.class);
    if (n != null) {
      appendNewlines(text, n.mNumNewlines);
      text.removeSpan(n);
    }
    Alignment a = getLast(text, Alignment.class);
    if (a != null) {
      setSpanFromMark(text, a, new AlignmentSpan.Standard(a.mAlignment));
    }
  }

  private static void handleBr(Editable text) {
    text.append('\n');
  }

  private void startLi(Editable text, Attributes attributes) {
    startBlockElement(text, attributes);
    ListContext context = mListStack.peekLast();
    int level = Math.max(0, mListStack.size() - 1);

    if (context != null && context.mType.equals("ordered")) {
      context.mIndex++;
      start(text, new List("ordered", context.mIndex, false, level));
    } else if (context != null && context.mType.equals("checked")) {
      String isChecked = attributes.getValue("", "checked");
      start(text, new List("checked", 0, isTruthyAttribute(isChecked), level));
    } else {
      start(text, new List("unordered", 0, false, level));
    }
  }

  private static <T> void endLi(Editable text, T style, EnrichedSpanFactory<T> spanFactory) {
    endBlockElement(text);

    List l = getLast(text, List.class);
    if (l != null) {
      if (l.mType.equals("ordered")) {
        EnrichedOrderedListSpan span = spanFactory.createOrderedListSpan(l.mIndex, style);
        span.setLevel(l.mLevel);
        setParagraphSpanFromMark(text, l, span);
      } else if (l.mType.equals("checked")) {
        EnrichedCheckboxListSpan span = spanFactory.createCheckboxListSpan(l.mChecked, style);
        span.setLevel(l.mLevel);
        setParagraphSpanFromMark(text, l, span);
      } else {
        EnrichedUnorderedListSpan span = spanFactory.createUnorderedListSpan(style);
        span.setLevel(l.mLevel);
        setParagraphSpanFromMark(text, l, span);
      }
    }

    endBlockElement(text);
  }

  private void startBlockquote(Editable text, Attributes attributes) {
    startBlockElement(text, attributes);
    start(text, new Blockquote());
  }

  private static <T> void endBlockquote(
      Editable text, T style, EnrichedSpanFactory<T> spanFactory) {
    endBlockElement(text);
    Blockquote last = getLast(text, Blockquote.class);
    setParagraphSpanFromMark(text, last, spanFactory.createBlockQuoteSpan(style));
  }

  private void startCodeBlock(Editable text, Attributes attributes) {
    startBlockElement(text, attributes);
    start(text, new CodeBlock());
  }

  private static <T> void endCodeBlock(Editable text, T style, EnrichedSpanFactory<T> spanFactory) {
    endBlockElement(text);
    CodeBlock last = getLast(text, CodeBlock.class);
    setParagraphSpanFromMark(text, last, spanFactory.createCodeBlockSpan(style));
  }

  private void startHeading(Editable text, int level, Attributes attributes) {
    startBlockElement(text, attributes);

    switch (level) {
      case 1:
        start(text, new H1());
        break;
      case 2:
        start(text, new H2());
        break;
      case 3:
        start(text, new H3());
        break;
      case 4:
        start(text, new H4());
        break;
      case 5:
        start(text, new H5());
        break;
      case 6:
        start(text, new H6());
        break;
      default:
        throw new IllegalArgumentException("Unsupported heading level: " + level);
    }
  }

  private static <T> void endHeading(
      Editable text, T style, EnrichedSpanFactory<T> spanFactory, int level) {
    endBlockElement(text);

    switch (level) {
      case 1:
        H1 lastH1 = getLast(text, H1.class);
        setParagraphSpanFromMark(text, lastH1, spanFactory.createH1Span(style));
        break;
      case 2:
        H2 lastH2 = getLast(text, H2.class);
        setParagraphSpanFromMark(text, lastH2, spanFactory.createH2Span(style));
        break;
      case 3:
        H3 lastH3 = getLast(text, H3.class);
        setParagraphSpanFromMark(text, lastH3, spanFactory.createH3Span(style));
        break;
      case 4:
        H4 lastH4 = getLast(text, H4.class);
        setParagraphSpanFromMark(text, lastH4, spanFactory.createH4Span(style));
        break;
      case 5:
        H5 lastH5 = getLast(text, H5.class);
        setParagraphSpanFromMark(text, lastH5, spanFactory.createH5Span(style));
        break;
      case 6:
        H6 lastH6 = getLast(text, H6.class);
        setParagraphSpanFromMark(text, lastH6, spanFactory.createH6Span(style));
        break;
      default:
        throw new IllegalArgumentException("Unsupported heading level: " + level);
    }
  }

  private static <T> T getLast(Spanned text, Class<T> kind) {
    /*
     * This knows that the last returned object from getSpans()
     * will be the most recently added.
     */
    T[] objs = text.getSpans(0, text.length(), kind);
    if (objs.length == 0) {
      return null;
    } else {
      return objs[objs.length - 1];
    }
  }

  private static void setSpanFromMark(Spannable text, Object mark, Object... spans) {
    int where = text.getSpanStart(mark);
    text.removeSpan(mark);
    int len = text.length();
    if (where != len) {
      for (Object span : spans) {
        text.setSpan(span, where, len, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
      }
    }
  }

  private static void setParagraphSpanFromMark(Editable text, Object mark, Object... spans) {
    int where = text.getSpanStart(mark);
    text.removeSpan(mark);
    int len = text.length();

    // Block spans require at least one character to be applied.
    if (isEmptyTag) {
      text.append(EnrichedConstants.ZWS);
      len++;
    }

    // Adjust the end position to exclude the newline character, if present
    if (len > 0 && text.charAt(len - 1) == '\n') {
      len--;
    }

    if (where != len) {
      for (Object span : spans) {
        text.setSpan(span, where, len, getSpanFlags(span, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE));
      }
    }
  }

  private static int getSpanFlags(Object span, int baseFlags) {
    if (span instanceof EnrichedBlockQuoteSpan) {
      return baseFlags | (1 << Spanned.SPAN_PRIORITY_SHIFT);
    }

    return baseFlags;
  }

  private static void start(Editable text, Object mark) {
    int len = text.length();
    text.setSpan(mark, len, len, Spannable.SPAN_INCLUSIVE_EXCLUSIVE);
  }

  private static void end(Editable text, Class kind, Object repl) {
    Object obj = getLast(text, kind);
    if (obj != null) {
      setSpanFromMark(text, obj, repl);
    }
  }

  private static <T> void startImg(
      Editable text, Attributes attributes, EnrichedSpanFactory<T> spanFactory) {
    String src = attributes.getValue("", "src");
    String width = attributes.getValue("", "width");
    String height = attributes.getValue("", "height");

    int len = text.length();
    text.append("￼");
    text.setSpan(
        spanFactory.createImageSpan(src, Integer.parseInt(width), Integer.parseInt(height)),
        len,
        text.length(),
        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
  }

  private static void startA(Editable text, Attributes attributes) {
    String href = attributes.getValue("", "href");
    start(text, new Href(href));
  }

  private static <T> void endA(Editable text, T style, EnrichedSpanFactory<T> spanFactory) {
    Href h = getLast(text, Href.class);
    if (h != null) {
      if (h.mHref != null) {
        setSpanFromMark(text, h, spanFactory.createLinkSpan(h.mHref, style));
      }
    }
  }

  private static void startMention(Editable mention, Attributes attributes) {
    String text = attributes.getValue("", "text");
    String indicator = attributes.getValue("", "indicator");

    Map<String, String> attributesMap = new HashMap<>();
    for (int i = 0; i < attributes.getLength(); i++) {
      String localName = attributes.getLocalName(i);

      if (!"text".equals(localName) && !"indicator".equals(localName)) {
        attributesMap.put(localName, attributes.getValue(i));
      }
    }

    start(mention, new Mention(indicator, text, attributesMap));
  }

  private static <T> void endMention(Editable text, T style, EnrichedSpanFactory<T> spanFactory) {
    Mention m = getLast(text, Mention.class);

    if (m == null) return;
    if (m.mText == null) return;

    setSpanFromMark(
        text, m, spanFactory.createMentionSpan(m.mText, m.mIndicator, m.mAttributes, style));
  }

  public void setDocumentLocator(Locator locator) {}

  public void startDocument() {}

  public void endDocument() {}

  public void startPrefixMapping(String prefix, String uri) {}

  public void endPrefixMapping(String prefix) {}

  public void startElement(String uri, String localName, String qName, Attributes attributes) {
    handleStartTag(localName, attributes);
  }

  public void endElement(String uri, String localName, String qName) {
    handleEndTag(localName);
  }

  public void characters(char[] ch, int start, int length) {
    if (mCodeBlockDepth > 0) {
      if (length > 0) isEmptyTag = false;
      mSpannableStringBuilder.append(new String(ch, start, length));
      return;
    }

    StringBuilder sb = new StringBuilder();

    /*
     * Ignore whitespace that immediately follows other whitespace;
     * newlines count as spaces.
     */
    for (int i = 0; i < length; i++) {
      char c = ch[i + start];
      if (c == ' ' || c == '\n') {
        char pred;
        int len = sb.length();
        if (len == 0) {
          len = mSpannableStringBuilder.length();
          if (len == 0) {
            pred = '\n';
          } else {
            pred = mSpannableStringBuilder.charAt(len - 1);
          }
        } else {
          pred = sb.charAt(len - 1);
        }
        if (pred != ' ' && pred != '\n') {
          sb.append(' ');
        }
      } else {
        sb.append(c);
      }
    }
    // Only mark the tag as non-empty if content was actually appended after
    // whitespace collapsing. A space-only list item (e.g. <li> </li>) would
    // have its space dropped when the preceding char is a newline, leaving
    // nothing to anchor a span — the ZWS placeholder must still be inserted.
    if (sb.length() > 0) isEmptyTag = false;
    mSpannableStringBuilder.append(sb);
  }

  public void ignorableWhitespace(char[] ch, int start, int length) {}

  public void processingInstruction(String target, String data) {}

  public void skippedEntity(String name) {}

  private static class H1 {}

  private static class H2 {}

  private static class H3 {}

  private static class H4 {}

  private static class H5 {}

  private static class H6 {}

  private static class Bold {}

  private static class Italic {}

  private static class Underline {}

  private static class Code {}

  private static class CodeBlock {}

  private static class Strikethrough {}

  private static class Blockquote {}

  private static class List {
    public int mIndex;
    public int mLevel;
    public String mType;
    public boolean mChecked;

    public List(String type, int index, boolean checked, int level) {
      mType = type;
      mIndex = index;
      mChecked = checked;
      mLevel = level;
    }
  }

  private static class ListContext {
    public int mIndex = 0;
    public String mType;

    public ListContext(String type) {
      mType = type;
    }
  }

  private static class Mention {
    public Map<String, String> mAttributes;
    public String mIndicator;
    public String mText;

    public Mention(String indicator, String text, Map<String, String> attributes) {
      mIndicator = indicator;
      mAttributes = attributes;
      mText = text;
    }
  }

  private static class Href {
    public String mHref;

    public Href(String href) {
      mHref = href;
    }
  }

  private static class Newline {
    private final int mNumNewlines;

    public Newline(int numNewlines) {
      mNumNewlines = numNewlines;
    }
  }

  private static class Alignment {
    private final Layout.Alignment mAlignment;

    public Alignment(Layout.Alignment alignment) {
      mAlignment = alignment;
    }
  }
}
