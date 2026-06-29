import { STRESS_TEST_HTML } from './stressTestHtml';

export interface InputExample {
  key: string;
  title: string;
  html: string;
}

export const INPUT_HTML_EXAMPLES: InputExample[] = [
  {
    key: 'full-stress',
    title: 'Full Stress',
    html: STRESS_TEST_HTML,
  },
  {
    key: 'quotes-in-lists',
    title: 'Quotes In Lists',
    html: `
<ul>
  <li>
    Bullet item containing a quote
    <blockquote>
      <p>Quote inside bullet item with <strong>bold</strong>, <em>italic</em>, <code>inline code</code>, <mention id="quote-list-user" text="@Quote List User" indicator="@">@Quote List User</mention>, and <a href="https://example.com">a link</a>.</p>
      <ol>
        <li>Ordered child inside quote</li>
        <li>Ordered child with nested bullet
          <ul>
            <li>Bullet grandchild inside quoted ordered item</li>
          </ul>
        </li>
      </ol>
    </blockquote>
  </li>
  <li>
    Bullet item containing nested quote and code
    <blockquote>
      <p>Nested quote before code block.</p>
      <pre><code>code block inside quote inside bullet
line 2</code></pre>
    </blockquote>
  </li>
</ul>
<ol>
  <li>
    Ordered item containing a quote
    <blockquote>
      <p>Quote inside ordered item with <mention id="ordered-quote" text="@Ordered Quote" indicator="@">@Ordered Quote</mention> and <mention id="ordered-quote-channel" text="#ordered-quote" indicator="#">#ordered-quote</mention>.</p>
      <ul data-type="checkbox">
        <li checked>Checked checkbox inside ordered quote</li>
        <li>Unchecked checkbox inside ordered quote</li>
      </ul>
    </blockquote>
  </li>
  <li>Ordered item after quote</li>
</ol>
<ul data-type="checkbox">
  <li checked>
    Checked checkbox containing a quote
    <blockquote>
      <p>Quote inside checked checkbox item with <code>inline code</code>.</p>
    </blockquote>
  </li>
  <li>
    Unchecked checkbox containing an ordered quote
    <blockquote>
      <ol>
        <li>Ordered child inside checkbox quote</li>
        <li>Second ordered child inside checkbox quote</li>
      </ol>
    </blockquote>
  </li>
</ul>
`,
  },
  {
    key: 'lists-in-quotes',
    title: 'Lists In Quotes',
    html: `
<blockquote>
  <p>Quote containing mixed list blocks with <strong>bold</strong>, <code>inline code</code>, and <a href="https://example.com">link text</a>.</p>
  <ul>
    <li>Bullet inside quote</li>
    <li>Bullet inside quote containing another quote
      <blockquote>
        <p>Quote inside list item inside quote.</p>
      </blockquote>
    </li>
  </ul>
  <ol>
    <li>Number inside quote</li>
    <li><em>Italic number inside quote</em></li>
  </ol>
  <ul data-type="checkbox">
    <li checked>Checked checkbox inside quote</li>
    <li>Unchecked checkbox inside quote</li>
  </ul>
</blockquote>
<blockquote>
  <blockquote>
    <p>Nested quote containing lists.</p>
    <ul>
      <li>Nested bullet in nested quote</li>
    </ul>
    <ol>
      <li>Nested number in nested quote</li>
    </ol>
  </blockquote>
</blockquote>
`,
  },
  {
    key: 'nested-block-matrix',
    title: 'Nested Block Matrix',
    html: `
<ul>
  <li>
    <p>Complex list item with every nested block type</p>
    <h4>Heading inside list item</h4>
    <p>Paragraph in complex list item with <strong>bold</strong>, <em>italic</em>, <u>underline</u>, <s>strikethrough</s>, <a href="https://example.com">link</a>, <code>inline code</code>, <mention id="complex-item" text="@Complex Item" indicator="@">@Complex Item</mention>, and <mention id="complex-channel" text="#complex-item" indicator="#">#complex-item</mention>.</p>
    <blockquote>
      <p>Quote in complex list item.</p>
      <ol>
        <li>Ordered child of quote in list item</li>
      </ol>
    </blockquote>
    <pre><code>Code block inside complex list item
Line 2 inside code block</code></pre>
    <ul data-type="checkbox">
      <li checked>Checked checkbox child in complex item</li>
      <li>Unchecked checkbox child in complex item</li>
    </ul>
  </li>
  <li>
    Sibling list item after complex blocks
    <ol>
      <li>Nested ordered child after quote/code block</li>
    </ol>
  </li>
</ul>
`,
  },
  {
    key: 'alternating-stack',
    title: 'Alternating Stack',
    html: `
<blockquote>
  <p>Outer quote before alternating list stack with <strong>bold</strong>, <code>inline code</code>, and <a href="https://example.com">link text</a>.</p>
  <ul>
    <li>
      Bullet inside quote before nested ordered list
      <ol>
        <li>
          Ordered child inside quoted bullet
          <blockquote>
            <p>Quote inside ordered child before checkbox list.</p>
            <ul data-type="checkbox">
              <li checked>
                Checked checkbox inside ordered quote
                <ul>
                  <li>Bullet child inside checked checkbox inside quote</li>
                </ul>
              </li>
              <li>
                Unchecked checkbox with nested ordered quote
                <blockquote>
                  <ol>
                    <li>Ordered child inside checkbox quote</li>
                    <li>Second ordered child inside checkbox quote</li>
                  </ol>
                </blockquote>
              </li>
            </ul>
          </blockquote>
        </li>
        <li>Ordered sibling after quoted checkbox stack</li>
      </ol>
    </li>
    <li>Bullet sibling after alternating stack</li>
  </ul>
</blockquote>
<p>Paragraph after alternating stack should return to root indentation.</p>
`,
  },
  {
    key: 'checkbox-quote-matrix',
    title: 'Checkbox Quote Matrix',
    html: `
<ul data-type="checkbox">
  <li checked>
    Checked root checkbox containing quote, list, and code
    <blockquote>
      <p>Quote inside checked checkbox with <mention id="matrix-user" text="@Matrix User" indicator="@">@Matrix User</mention> and <mention id="matrix-channel" text="#matrix" indicator="#">#matrix</mention>.</p>
      <ol>
        <li>Ordered child inside checked checkbox quote</li>
        <li>
          Ordered child containing nested checkbox list
          <ul data-type="checkbox">
            <li checked>Checked grandchild checkbox inside quoted ordered item</li>
            <li>
              Unchecked grandchild checkbox containing nested quote
              <blockquote>
                <p>Nested quote inside checkbox grandchild.</p>
                <ul>
                  <li>Bullet inside nested checkbox quote</li>
                </ul>
              </blockquote>
            </li>
          </ul>
        </li>
      </ol>
      <pre><code>code block inside checked checkbox quote
line 2 stays inside quote
line 3 keeps code padding</code></pre>
    </blockquote>
  </li>
  <li>
    Unchecked root checkbox after deep checked item
    <ul>
      <li>Bullet child after previous quoted checkbox</li>
    </ul>
  </li>
</ul>
`,
  },
  {
    key: 'sibling-recovery-stack',
    title: 'Sibling Recovery Stack',
    html: `
<ol>
  <li>
    Ordered root with nested quote and checkbox branch
    <blockquote>
      <p>Quote inside ordered root before unordered branch.</p>
      <ul>
        <li>
          Bullet inside ordered quote
          <ul data-type="checkbox">
            <li checked>
              Checked checkbox inside quoted bullet
              <blockquote>
                <p>Deep quote inside checked checkbox inside bullet inside ordered quote.</p>
              </blockquote>
            </li>
            <li>Unchecked checkbox sibling inside quoted bullet</li>
          </ul>
        </li>
        <li>Bullet sibling after checkbox branch inside quote</li>
      </ul>
    </blockquote>
  </li>
  <li>Ordered root sibling after quote branch</li>
  <li>
    Ordered root containing checkbox list after quote branch
    <ul data-type="checkbox">
      <li checked>Checked checkbox after quote branch</li>
      <li>
        Unchecked checkbox containing quote with ordered children
        <blockquote>
          <ol>
            <li>Ordered child inside recovery checkbox quote</li>
            <li>Second ordered child inside recovery checkbox quote</li>
          </ol>
        </blockquote>
      </li>
    </ul>
  </li>
</ol>
<ul>
  <li>Root bullet after ordered recovery stack</li>
  <li>
    Root bullet containing final quote
    <blockquote>
      <p>Final quote after recovery stack should align with root bullet context.</p>
    </blockquote>
  </li>
</ul>
`,
  },
  {
    key: 'alignment-blocks',
    title: 'Alignment Blocks',
    html: `
<p style="text-align: center">Centered paragraph before block combinations.</p>
<blockquote style="text-align: center">
  <p>Centered quote containing centered text and <code>inline code</code>.</p>
</blockquote>
<blockquote style="text-align: right">
  <p>Right aligned quote paragraph with <a href="https://example.com">link</a>.</p>
</blockquote>
<ul>
  <li style="text-align: left">Left aligned bullet with normal text.</li>
  <li style="text-align: center">Centered bullet with <strong>bold text</strong>.</li>
  <li style="text-align: right">Right aligned bullet with <em>italic text</em>.</li>
</ul>
<ol>
  <li style="text-align: center">Centered ordered item with <code>inline code</code>.</li>
  <li>Ordered item containing a quote
    <blockquote>
      <p>Quote inside ordered item.</p>
    </blockquote>
  </li>
  <li style="text-align: right">Right ordered item after quote.</li>
</ol>
<ul data-type="checkbox">
  <li checked style="text-align: center">Centered checked checkbox item</li>
  <li style="text-align: right">Right unchecked checkbox item</li>
</ul>
`,
  },
  {
    key: 'media-blocks',
    title: 'Media Blocks',
    html: `
<p>Image before mixed blocks: <img src="https://reactnative.dev/img/tiny_logo.png" width="64" height="64" /></p>
<blockquote>
  <p>Quote with image and mention: <img src="https://reactnative.dev/img/tiny_logo.png" width="48" height="48" /> <mention id="media-user" text="@Media User" indicator="@">@Media User</mention></p>
</blockquote>
<ul>
  <li>List item image: <img src="https://reactnative.dev/img/tiny_logo.png" width="48" height="48" /></li>
  <li>List item containing image quote
    <blockquote>
      <p>Quoted image: <img src="https://reactnative.dev/img/tiny_logo.png" width="40" height="40" /></p>
    </blockquote>
  </li>
</ul>
<ul data-type="checkbox">
  <li checked>Checked image checkbox <img src="https://reactnative.dev/img/tiny_logo.png" width="40" height="40" /></li>
  <li>Unchecked image checkbox with <mention id="media-channel" text="#media" indicator="#">#media</mention></li>
</ul>
`,
  },
];
