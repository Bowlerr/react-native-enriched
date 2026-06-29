import { STRESS_TEST_HTML } from './stressTestHtml';
import { INPUT_HTML_EXAMPLES } from './inputExamples';

export interface TextViewerExample {
  key: string;
  title: string;
  html: string;
}

const INPUT_EXAMPLES_FOR_TEXT_VIEWER: TextViewerExample[] =
  INPUT_HTML_EXAMPLES.filter((example) => example.key !== 'full-stress');

export const TEXT_VIEWER_HTML_EXAMPLES: TextViewerExample[] = [
  {
    key: 'basics',
    title: 'Basics',
    html: `
<p>Plain paragraph with normal body styling.</p>
<p><strong>Bold</strong>, <em>italic</em>, <u>underline</u>, <s>strike</s>, <a href="https://example.com">link</a>, and <code>inline code</code>.</p>
<p><strong><em><u><s>All inline marks together</s></u></em></strong></p>
`,
  },
  {
    key: 'headings',
    title: 'Headings',
    html: `
<h1>Heading 1 with <strong>bold</strong></h1>
<h2>Heading 2 with <em>italic</em></h2>
<h3>Heading 3 with <u>underline</u></h3>
<h4>Heading 4 with <s>strike</s></h4>
<h5>Heading 5 with <code>code</code></h5>
<h6>Heading 6 with <a href="https://example.com">link</a></h6>
`,
  },
  {
    key: 'inline-combos',
    title: 'Inline Combos',
    html: `
<p><strong><em>Bold italic</em></strong></p>
<p><strong><u>Bold underline</u></strong></p>
<p><em><u>Italic underline</u></em></p>
<p><strong><s>Bold strike</s></strong></p>
<p><em><s>Italic strike</s></em></p>
<p><strong><em><u><s><a href="https://example.com"><code>All marks code link</code></a></s></u></em></strong></p>
`,
  },
  {
    key: 'style-surface',
    title: 'Style Surface',
    html: `
<h1>H1 configured font size and bold weight</h1>
<h2>H2 configured font size and bold weight</h2>
<h3>H3 configured font size and bold weight</h3>
<h4>H4 configured font size and bold weight</h4>
<h5>H5 configured font size and bold weight</h5>
<h6>H6 configured font size and bold weight</h6>
<blockquote>
  <p>Blockquote style token check: navy text, navy vertical border, configured border width, and configured gap.</p>
</blockquote>
<p>Inline code style token check: <code>Purple text on yellow inline code background</code>.</p>
<p>Link style token check: <a href="https://example.com">green underlined link text</a>.</p>
<p>Mention style token check: <mention id="surface-user" text="@Surface User" indicator="@">@Surface User</mention> and <mention id="surface-channel" text="#surface-channel" indicator="#">#surface-channel</mention>.</p>
<pre><code>Code block style token check
Green text on grey rounded background</code></pre>
<ul>
  <li>Unordered style token check: aquamarine bullet, configured bullet size, gap, and margin.</li>
</ul>
<ol>
  <li>Ordered style token check: navy bold marker, configured gap, and margin.</li>
</ol>
<ul data-type="checkbox">
  <li checked>Checkbox style token check: navy box, configured size, gap, and margin.</li>
  <li>Unchecked checkbox style token check.</li>
</ul>
`,
  },
  {
    key: 'html-normalizer',
    title: 'HTML Normalizer',
    html: `
<div style="font-weight: 700; text-align: center">Centered bold div normalized to paragraph.</div>
<div>Div line one<br>Div line two after br</div>
<p>
  <b>b tag</b>,
  <strong>strong tag</strong>,
  <i>i tag</i>,
  <em>em tag</em>,
  <u>u tag</u>,
  <ins>ins tag</ins>,
  <s>s tag</s>,
  <del>del tag</del>,
  and <strike>strike tag</strike>.
</p>
<p>
  <span style="font-weight: 700">Span bold</span>,
  <span style="font-style: italic">span italic</span>,
  <span style="text-decoration: underline">span underline</span>,
  and <span style="text-decoration: line-through">span strikethrough</span>.
</p>
<table>
  <tr>
    <td>Table cell A</td>
    <td>Table cell B</td>
  </tr>
</table>
<ul data-type="checkboxList">
  <li data-checked="true">CheckboxList alias checked item</li>
  <li data-checked="false">CheckboxList alias unchecked item</li>
</ul>
`,
  },
  {
    key: 'quotes',
    title: 'Quotes',
    html: `
<blockquote>
  <p>Quote level 1 with <strong>bold</strong> and <a href="https://example.com">link</a>.</p>
  <blockquote>
    <p>Quote level 2 with <em>italic</em>.</p>
    <blockquote>
      <p>Quote level 3 with <code>inline code</code>.</p>
    </blockquote>
  </blockquote>
</blockquote>
`,
  },
  {
    key: 'lists',
    title: 'Lists',
    html: `
<ul>
  <li>Bullet level 1</li>
  <li>Bullet parent
    <ul>
      <li>Bullet level 2</li>
      <li>Bullet level 2 with <strong>bold</strong></li>
    </ul>
  </li>
</ul>
<ol>
  <li>Ordered level 1</li>
  <li>Ordered parent
    <ol>
      <li>Ordered level 2</li>
      <li>Ordered level 2 with <em>italic</em></li>
    </ol>
  </li>
</ol>
`,
  },
  {
    key: 'checkboxes',
    title: 'Checkboxes',
    html: `
<ul data-type="checkbox">
  <li checked>Checked root checkbox</li>
  <li>Unchecked root checkbox</li>
  <li checked><strong><code>Styled checked checkbox</code></strong></li>
</ul>
<ol>
  <li>Ordered parent with checkbox children
    <ul data-type="checkbox">
      <li checked>Checked nested checkbox</li>
      <li>Unchecked nested checkbox</li>
    </ul>
  </li>
</ol>
<blockquote>
  <ul data-type="checkbox">
    <li checked>Checked checkbox inside quote</li>
    <li>Unchecked checkbox inside quote</li>
  </ul>
</blockquote>
`,
  },
  {
    key: 'alignment',
    title: 'Alignment',
    html: `
<p style="text-align: left">Left paragraph alignment with regular text.</p>
<p style="text-align: center">Center paragraph alignment with <strong>bold</strong>.</p>
<p style="text-align: right">Right paragraph alignment with <em>italic</em>.</p>
<p style="text-align: justify">Justify paragraph alignment with enough text to wrap across multiple lines so spacing can be inspected across the full width of the viewer.</p>
<h2 style="text-align: left">Left heading</h2>
<h2 style="text-align: center">Center heading</h2>
<h2 style="text-align: right">Right heading</h2>
<blockquote style="text-align: center">
  <p>Centered quote paragraph.</p>
</blockquote>
<ul>
  <li style="text-align: left">Left bullet alignment</li>
  <li style="text-align: center">Center bullet alignment</li>
  <li style="text-align: right">Right bullet alignment</li>
</ul>
<ol>
  <li style="text-align: left">Left ordered alignment</li>
  <li style="text-align: center">Center ordered alignment</li>
  <li style="text-align: right">Right ordered alignment</li>
</ol>
<ul data-type="checkbox">
  <li checked style="text-align: left">Left checkbox alignment</li>
  <li checked style="text-align: center">Center checkbox alignment</li>
  <li style="text-align: right">Right checkbox alignment</li>
</ul>
<pre style="text-align: center"><code>Centered code block
Line 2 remains centered</code></pre>
`,
  },
  {
    key: 'mentions',
    title: 'Mentions',
    html: `
<p>Mentions: <mention id="user-one" text="@Ada Lovelace" indicator="@">@Ada Lovelace</mention> and <mention id="general" text="#general" indicator="#">#general</mention>.</p>
<p><strong>Styled mention:</strong> <strong><mention id="styled-user" text="@Styled User" indicator="@">@Styled User</mention></strong></p>
<p><em>Italic mention:</em> <em><mention id="italic-user" text="@Italic User" indicator="@">@Italic User</mention></em></p>
<p><u>Underlined channel mention:</u> <u><mention id="underlined-channel" text="#underlined-channel" indicator="#">#underlined-channel</mention></u></p>
`,
  },
  {
    key: 'media',
    title: 'Media',
    html: `
<p>Image between text: before image <img src="https://reactnative.dev/img/tiny_logo.png" width="96" height="96" /> after image.</p>
<blockquote>
  <p>Quote with image: <img src="https://reactnative.dev/img/tiny_logo.png" width="72" height="72" /></p>
</blockquote>
<ul>
  <li>List item image: <img src="https://reactnative.dev/img/tiny_logo.png" width="48" height="48" /></li>
</ul>
`,
  },
  {
    key: 'code-blocks',
    title: 'Code Blocks',
    html: `
<p>Inline code before a block: <code>const value = 1</code>.</p>
<pre><code>function example() {
  return "Code block";
}</code></pre>
<blockquote>
  <pre><code>Code block inside quote
Line 2 inside quote</code></pre>
</blockquote>
<ul>
  <li>List item before code block
    <pre><code>Code block inside list item
Line 2 inside list item</code></pre>
  </li>
</ul>
`,
  },
  {
    key: 'blocks-in-lists',
    title: 'Blocks In Lists',
    html: `
<ul>
  <li>
    Complex bullet item
    <h4>Nested heading in bullet item</h4>
    <p>Nested paragraph with <strong>bold</strong>, <em>italic</em>, and <code>code</code>.</p>
    <blockquote>Nested quote inside bullet item.</blockquote>
    <ol>
      <li>Ordered child</li>
      <li>Ordered child with checkbox list
        <ul data-type="checkbox">
          <li checked>Checked checkbox grandchild</li>
          <li>Unchecked checkbox grandchild</li>
        </ul>
      </li>
    </ol>
  </li>
</ul>
`,
  },
  ...INPUT_EXAMPLES_FOR_TEXT_VIEWER,
  {
    key: 'truncation',
    title: 'Truncation',
    html: `
<p>Truncation fixture starts with a deliberately long first paragraph containing bold text, italic text, inline code, and a link so numberOfLines plus head, middle, tail, and clip ellipsize modes can be inspected visually in the viewer without relying on text discovery alone.</p>
<p>Second paragraph should disappear when numberOfLines is set to one.</p>
`,
  },
  {
    key: 'full-stress',
    title: 'Full Stress',
    html: STRESS_TEST_HTML,
  },
];
