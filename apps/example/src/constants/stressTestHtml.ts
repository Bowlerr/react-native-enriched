export const STRESS_TEST_HTML = `<!-- BASIC OPTIONS -->

<p>This is a normal example sentence with no formatting applied.</p>

<p>
  This example sentence includes <strong>bold text</strong>,
  <em>italic text</em>, <u>underlined text</u>,
  <s>strikethrough text</s>,
  a <a href="https://example.com">link</a>,
  and <code>inline code</code>.
</p>

<p><strong>Bold</strong></p>

<p><em>Italic</em></p>

<p><s>Strikethrough</s></p>

<p><u>Underline</u></p>

<p>
  <a href="https://example.com">
    Link
  </a>
</p>

<h1>Heading 1</h1>
<h2>Heading 2</h2>
<h3>Heading 3</h3>
<h4>Heading 4</h4>
<h5>Heading 5</h5>
<h6>Heading 6</h6>

<blockquote>
  Quote
</blockquote>

<!-- NESTED QUOTE LEVELS -->

<blockquote>
  <p>Quote Level 1</p>
  <blockquote>
    <p>Quote Level 2</p>
    <blockquote>
      <p>Quote Level 3</p>
      <blockquote>
        <p>Quote Level 4</p>
      </blockquote>
      <p>Back to Quote Level 3</p>
    </blockquote>
    <p>Back to Quote Level 2</p>
  </blockquote>
  <p>Back to Quote Level 1</p>
</blockquote>

<p><code>Inline Code</code></p>

<pre><code>Code Block
Line 2
Line 3</code></pre>

<!-- BULLETS -->

<ul>
  <li>Bullet</li>
</ul>

<ul>
  <li>
    Increase Level
    <ul>
      <li>Nested Bullet Level 2</li>
      <li>
        Nested Bullet Level 3
        <ul>
          <li>Nested Bullet Level 4</li>
        </ul>
      </li>
    </ul>
  </li>

  <li>Decrease Level</li>
</ul>

<!-- NUMBERS -->

<ol>
  <li>Number</li>
</ol>

<ol>
  <li>
    Number Level 1
    <ol>
      <li>
        Number Level 2
        <ol>
          <li>Number Level 3</li>
        </ol>
      </li>
    </ol>
  </li>
</ol>

<!-- DOUBLE COMBINATIONS -->

<p><strong><em>Bold Italic</em></strong></p>

<p><strong><u>Bold Underline</u></strong></p>

<p><em><u>Italic Underline</u></em></p>

<p><s><u>Strikethrough Underline</u></s></p>

<p><strong><s>Bold Strikethrough</s></strong></p>

<p><em><s>Italic Strikethrough</s></em></p>

<p>
  <strong>
    <a href="https://example.com">
      Bold Link
    </a>
  </strong>
</p>

<p>
  <em>
    <a href="https://example.com">
      Italic Link
    </a>
  </em>
</p>

<p>
  <s>
    <a href="https://example.com">
      Strikethrough Link
    </a>
  </s>
</p>

<p><strong><code>Bold Code</code></strong></p>

<p><em><code>Italic Code</code></em></p>

<p><s><code>Strikethrough Code</code></s></p>

<p>
  <a href="https://example.com">
    <code>Code Link</code>
  </a>
</p>

<!-- TRIPLE COMBINATIONS -->

<p><strong><em><s>Bold Italic Strikethrough</s></em></strong></p>

<p><strong><em><u>Bold Italic Underline</u></em></strong></p>

<p><strong><s><u>Bold Strikethrough Underline</u></s></strong></p>

<p><em><s><u>Italic Strikethrough Underline</u></s></em></p>

<p>
  <strong><em>
    <a href="https://example.com">
      Bold Italic Link
    </a>
  </em></strong>
</p>

<p>
  <strong><s>
    <a href="https://example.com">
      Bold Strikethrough Link
    </a>
  </s></strong>
</p>

<p>
  <em><s>
    <a href="https://example.com">
      Italic Strikethrough Link
    </a>
  </s></em>
</p>

<p><strong><em><code>Bold Italic Code</code></em></strong></p>

<p><strong><s><code>Bold Strikethrough Code</code></s></strong></p>

<p><em><s><code>Italic Strikethrough Code</code></s></em></p>

<p>
  <strong>
    <a href="https://example.com">
      <code>Bold Code Link</code>
    </a>
  </strong>
</p>

<p>
  <em>
    <a href="https://example.com">
      <code>Italic Code Link</code>
    </a>
  </em>
</p>

<p>
  <s>
    <a href="https://example.com">
      <code>Strikethrough Code Link</code>
    </a>
  </s>
</p>

<!-- ALL FORMATTING -->

<p>
  <strong><em><s><u>
    <a href="https://example.com">
      All Formatting Link
    </a>
  </u></s></em></strong>
</p>

<p>
  <strong><em><s><u><code>
    All Formatting Code
  </code></u></s></em></strong>
</p>

<p>
  <strong><em><s><u>
    <a href="https://example.com">
      <code>All Inline Formatting Code Link</code>
    </a>
  </u></s></em></strong>
</p>

<p>
  This sentence tests everything inline:
  <strong>bold</strong>,
  <em>italic</em>,
  <u>underline</u>,
  <s>struck text</s>,
  <a href="https://example.com">linked text</a>,
  <code>inline code</code>,
  <strong><em>bold italic</em></strong>,
  <strong><s>bold strikethrough</s></strong>,
  <em><s>italic strikethrough</s></em>,
  <strong><em><s>bold italic strikethrough</s></em></strong>,
  <strong><em><s><u>bold italic strikethrough underline</u></s></em></strong>,
  and
  <strong><em><s>
    <a href="https://example.com">
      <code>bold italic strikethrough code link</code>
    </a>
  </s></em></strong>.
</p>

<!-- HEADING COMBINATIONS -->

<h1><strong>Bold Heading</strong></h1>

<h1><em>Italic Heading</em></h1>

<h1><u>Underline Heading</u></h1>

<h1><s>Strikethrough Heading</s></h1>

<h1>
  <a href="https://example.com">
    Linked Heading
  </a>
</h1>

<h1><code>Code Heading</code></h1>

<h1><strong><em>Bold Italic Heading</em></strong></h1>

<h1><strong><s>Bold Strikethrough Heading</s></strong></h1>

<h1><em><s>Italic Strikethrough Heading</s></em></h1>

<h1><strong><em><u>Bold Italic Underline Heading</u></em></strong></h1>

<h1>
  <strong><em><s><u>
    Full Styled Heading
  </u></s></em></strong>
</h1>

<h1>
  <strong>
    <a href="https://example.com">
      Bold Linked Heading
    </a>
  </strong>
</h1>

<h1>
  <em>
    <a href="https://example.com">
      Italic Linked Heading
    </a>
  </em>
</h1>

<h1>
  <s>
    <a href="https://example.com">
      Strikethrough Linked Heading
    </a>
  </s>
</h1>

<h1>
  <strong><em><s>
    <a href="https://example.com">
      Full Styled Linked Heading
    </a>
  </s></em></strong>
</h1>

<h1>
  <a href="https://example.com">
    <code>Code Linked Heading</code>
  </a>
</h1>

<h2><strong>Bold Heading 2</strong></h2>

<h3><em>Italic Heading 3</em></h3>

<h4><u>Underline Heading 4</u></h4>

<h5><s>Strikethrough Heading 5</s></h5>

<h6><code>Code Heading 6</code></h6>

<!-- QUOTE COMBINATIONS -->

<blockquote>
  This is a normal quote sentence with no extra inline formatting.
</blockquote>

<blockquote>
  <strong>Bold Quote</strong>
</blockquote>

<blockquote>
  <em>Italic Quote</em>
</blockquote>

<blockquote>
  <u>Underline Quote</u>
</blockquote>

<blockquote>
  <s>Strikethrough Quote</s>
</blockquote>

<blockquote>
  <a href="https://example.com">
    Link Quote
  </a>
</blockquote>

<blockquote>
  <code>Code Quote</code>
</blockquote>

<blockquote>
  This quote contains <strong>bold</strong>,
  <em>italic</em>, <u>underline</u>,
  <s>strikethrough</s>,
  a <a href="https://example.com">link</a>,
  and <code>inline code</code>.
</blockquote>

<blockquote>
  <strong><em>Bold Italic Quote</em></strong>
</blockquote>

<blockquote>
  <strong><em><u>Bold Italic Underline Quote</u></em></strong>
</blockquote>

<blockquote>
  <strong><code>Bold Code Quote</code></strong>
</blockquote>

<blockquote>
  <em><code>Italic Code Quote</code></em>
</blockquote>

<blockquote>
  <s><code>Strikethrough Code Quote</code></s>
</blockquote>

<blockquote>
  <a href="https://example.com">
    <code>Code Link Quote</code>
  </a>
</blockquote>

<blockquote>
  <strong><em><s><u>
    Full Styled Quote
  </u></s></em></strong>
</blockquote>

<blockquote>
  <strong><em><s><u>
    <a href="https://example.com">
      <code>Full Styled Code Link Quote</code>
    </a>
  </u></s></em></strong>
</blockquote>

<!-- BULLET COMBINATIONS -->

<ul>
  <li>This is a normal bullet sentence.</li>

  <li><strong>Bold Bullet</strong></li>

  <li><em>Italic Bullet</em></li>

  <li><u>Underline Bullet</u></li>

  <li><s>Strikethrough Bullet</s></li>

  <li>
    <a href="https://example.com">
      Link Bullet
    </a>
  </li>

  <li><code>Code Bullet</code></li>

  <li><strong><em>Bold Italic Bullet</em></strong></li>

  <li><strong><em><s><u>Full Styled Bullet</u></s></em></strong></li>

  <li>
    This bullet contains <strong>bold</strong>,
    <em>italic</em>, <u>underline</u>,
    <s>strikethrough</s>,
    a <a href="https://example.com">link</a>,
    and <code>inline code</code>.
  </li>

  <li>
    <a href="https://example.com">
      <code>Code Link Bullet</code>
    </a>
  </li>

  <li>
    <strong><em><s><u>
      <a href="https://example.com">
        <code>Full Styled Code Link Bullet</code>
      </a>
    </u></s></em></strong>
  </li>
</ul>

<!-- NUMBER COMBINATIONS -->

<ol>
  <li>This is a normal numbered sentence.</li>

  <li><strong>Bold Number</strong></li>

  <li><em>Italic Number</em></li>

  <li><u>Underline Number</u></li>

  <li><s>Strikethrough Number</s></li>

  <li>
    <a href="https://example.com">
      Link Number
    </a>
  </li>

  <li><code>Code Number</code></li>

  <li><strong><em>Bold Italic Number</em></strong></li>

  <li><strong><em><s><u>Full Styled Number</u></s></em></strong></li>

  <li>
    This numbered item contains <strong>bold</strong>,
    <em>italic</em>, <u>underline</u>,
    <s>strikethrough</s>,
    a <a href="https://example.com">link</a>,
    and <code>inline code</code>.
  </li>

  <li>
    <a href="https://example.com">
      <code>Code Link Number</code>
    </a>
  </li>

  <li>
    <strong><em><s><u>
      <a href="https://example.com">
        <code>Full Styled Code Link Number</code>
      </a>
    </u></s></em></strong>
  </li>
</ol>

<!-- CLEAR INCREASE / DECREASE LEVEL EXAMPLES -->

<ul>
  <li>Bullet Level 1</li>

  <li>
    Bullet Level 1 with increased level below
    <ul>
      <li>Bullet Level 2</li>

      <li>
        Bullet Level 2 with increased level below
        <ul>
          <li>Bullet Level 3</li>

          <li>
            Bullet Level 3 with increased level below
            <ul>
              <li>Bullet Level 4</li>
            </ul>
          </li>

          <li>Back to Bullet Level 3</li>
        </ul>
      </li>

      <li>Back to Bullet Level 2</li>
    </ul>
  </li>

  <li>Back to Bullet Level 1 after decrease level</li>
</ul>

<ol>
  <li>Number Level 1</li>

  <li>
    Number Level 1 with increased level below
    <ol>
      <li>Number Level 2</li>

      <li>
        Number Level 2 with increased level below
        <ol>
          <li>Number Level 3</li>

          <li>
            Number Level 3 with increased level below
            <ol>
              <li>Number Level 4</li>
            </ol>
          </li>

          <li>Back to Number Level 3</li>
        </ol>
      </li>

      <li>Back to Number Level 2</li>
    </ol>
  </li>

  <li>Back to Number Level 1 after decrease level</li>
</ol>

<!-- MIXED NESTED COMBINATIONS -->

<ul>
  <li>
    <strong>Bold Parent</strong>
    <ul>
      <li><em>Italic Child</em></li>

      <li><s>Strikethrough Child</s></li>

      <li>
        <a href="https://example.com">
          Linked Child
        </a>
      </li>

      <li><code>Code Child</code></li>
    </ul>
  </li>
</ul>

<ol>
  <li>
    <strong>Bold Parent Number</strong>
    <ol>
      <li><em>Italic Child Number</em></li>

      <li><s>Strikethrough Child Number</s></li>

      <li>
        <a href="https://example.com">
          Linked Child Number
        </a>
      </li>

      <li><code>Code Child Number</code></li>
    </ol>
  </li>
</ol>

<!-- MIXED BULLET / NUMBER NESTING -->

<ul>
  <li>
    Bullet parent
    <ol>
      <li>Number child inside bullet</li>

      <li>
        Another number child
        <ul>
          <li>Bullet grandchild inside number</li>
        </ul>
      </li>
    </ol>
  </li>
</ul>

<ol>
  <li>
    Number parent
    <ul>
      <li>Bullet child inside number</li>

      <li>
        Another bullet child
        <ol>
          <li>Number grandchild inside bullet</li>
        </ol>
      </li>
    </ul>
  </li>
</ol>

<!-- CHECKBOX LISTS -->

<ul data-type="checkbox">
  <li checked>Checked checkbox item</li>
  <li>Unchecked checkbox item</li>
  <li checked><strong>Bold checked checkbox item</strong></li>
  <li><em>Italic unchecked checkbox item</em></li>
  <li>
    Checkbox item with <u>underline</u>,
    <s>strikethrough</s>, <a href="https://example.com">link</a>,
    and <code>inline code</code>.
  </li>
</ul>

<ul data-type="checkbox">
  <li checked>
    Checkbox parent checked
    <ul data-type="checkbox">
      <li>Nested checkbox level 2 unchecked</li>
      <li checked>
        Nested checkbox level 2 checked
        <ul data-type="checkbox">
          <li checked>Nested checkbox level 3 checked</li>
        </ul>
      </li>
    </ul>
  </li>
  <li>Back to checkbox level 1 unchecked</li>
</ul>

<!-- ALIGNMENTS -->

<p style="text-align: left">
  Left aligned paragraph with <strong>bold</strong> and <code>inline code</code>.
</p>

<p style="text-align: center">
  Center aligned paragraph with <em>italic</em> and
  <a href="https://example.com">link</a>.
</p>

<p style="text-align: right">
  Right aligned paragraph with <u>underline</u> and <s>strikethrough</s>.
</p>

<p style="text-align: justify">
  Justified paragraph to cover the command API. This line includes enough text
  to wrap on mobile so text alignment can be inspected across multiple lines.
</p>

<h2 style="text-align: center">Center Aligned Heading</h2>

<blockquote style="text-align: right">
  Right aligned quote with <code>inline code</code>.
</blockquote>

<!-- MENTIONS AND IMAGES -->

<p>
  User mention:
  <mention text="@Ada Lovelace" indicator="@" id="user-ada" type="user">
    @Ada Lovelace
  </mention>
</p>

<p>
  Channel mention:
  <mention text="#care-plan" indicator="#" id="channel-care-plan" type="channel">
    #care-plan
  </mention>
</p>

<p>
  Mixed mention sentence with
  <mention text="@Grace Hopper" indicator="@" id="user-grace" type="user">
    @Grace Hopper
  </mention>
  and
  <mention text="#handover" indicator="#" id="channel-handover" type="channel">
    #handover
  </mention>.
</p>

<p>Image below:</p>

<img src="https://reactnative.dev/img/tiny_logo.png" width="96" height="96" />

<!-- BLOCK COMBINATION EXAMPLES -->

<blockquote>
  <h1>Heading Inside Quote</h1>

  <p>
    Quote paragraph with <strong>bold</strong>,
    <em>italic</em>,
    <s>strikethrough</s>,
    a <a href="https://example.com">link</a>,
    and <code>inline code</code>.
  </p>
</blockquote>

<blockquote>
  <ul>
    <li>Bullet inside quote</li>
    <li><strong>Bold bullet inside quote</strong></li>
  </ul>
</blockquote>

<blockquote>
  <ol>
    <li>Number inside quote</li>
    <li><em>Italic number inside quote</em></li>
  </ol>
</blockquote>

<!-- VERY COMPLEX COMBINATION / STRESS TEST -->

<blockquote>
  <h1>
    <strong><em><s>
      <a href="https://example.com">
        Very Complex Heading Link
      </a>
    </s></em></strong>
  </h1>

  <p>
    This very complex example sentence starts as normal text, then uses
    <strong>bold</strong>,
    <em>italic</em>,
    <u>underline</u>,
    <s>strikethrough</s>,
    <a href="https://example.com">a normal link</a>,
    <code>inline code</code>,
    <strong><em>bold italic</em></strong>,
    <strong><s>bold strikethrough</s></strong>,
    <em><s>italic strikethrough</s></em>,
    <strong><em><s>bold italic strikethrough</s></em></strong>,
    <strong><em><s><u>bold italic strikethrough underline</u></s></em></strong>,
    and finally
    <strong><em><s>
      <a href="https://example.com">
        <code>bold italic strikethrough code link</code>
      </a>
    </s></em></strong>.
  </p>

  <ul>
    <li>
      <strong><u>Bullet Level 1 Bold Underline Parent</u></strong>

      <ol>
        <li>
          <em>Number Level 2 Italic Child</em>

          <ul>
            <li>
              <s>Bullet Level 3 Strikethrough Child</s>

              <ol>
                <li>
                  <a href="https://example.com">
                    Number Level 4 Linked Child
                  </a>
                </li>

                <li>
                  <code>Number Level 4 Inline Code Child</code>
                </li>

                <li>
                  <strong><em><s><u>
                    <a href="https://example.com">
                      <code>Number Level 4 Full Styled Code Link Child</code>
                    </a>
                  </u></s></em></strong>
                </li>
              </ol>
            </li>

            <li>
              Back to Bullet Level 3 after decrease level
            </li>
          </ul>
        </li>

        <li>
          Back to Number Level 2 after decrease level
        </li>
      </ol>
    </li>

    <li>
      Back to Bullet Level 1 after multiple decrease levels
    </li>

    <li>
      <strong><em><s><u>
        <a href="https://example.com">
          <code>Full Styled Bullet At Root Level</code>
        </a>
      </u></s></em></strong>
    </li>
  </ul>

  <ol>
    <li>
      <strong>Number Level 1 Bold Parent</strong>

      <ul>
        <li>
          <em>Bullet Level 2 Italic Child</em>

          <ol>
            <li>
              <s>Number Level 3 Strikethrough Child</s>

              <ul>
                <li>
                  <a href="https://example.com">
                    Bullet Level 4 Linked Child
                  </a>
                </li>

                <li>
                  <code>Bullet Level 4 Code Child</code>
                </li>

                <li>
                  <strong><em><s><u>
                    <a href="https://example.com">
                      <code>Bullet Level 4 Full Styled Code Link Child</code>
                    </a>
                  </u></s></em></strong>
                </li>
              </ul>
            </li>

            <li>
              Back to Number Level 3 after decrease level
            </li>
          </ol>
        </li>

        <li>
          Back to Bullet Level 2 after decrease level
        </li>
      </ul>
    </li>

    <li>
      Back to Number Level 1 after multiple decrease levels
    </li>
  </ol>

  <pre><code>Very Complex Code Block
Line 2: bold + italic + strikethrough are not active inside this block
Line 3: links are plain text inside this block
Line 4: nested lists above test increase and decrease level behavior
Line 5: end of complex code block</code></pre>
</blockquote>

<!-- VERY COMPLEX EXAMPLE OUTSIDE QUOTE -->

<h1>
  <strong><em><s>
    Complex Standalone Heading
  </s></em></strong>
</h1>

<p>
  Before the list starts, this paragraph contains
  <strong>bold</strong>,
  <em>italic</em>,
  <u>underline</u>,
  <s>strikethrough</s>,
  <a href="https://example.com">link</a>,
  <code>code</code>,
  and
  <strong><em><s><u>
    <a href="https://example.com">
      <code>all formatting together</code>
    </a>
  </u></s></em></strong>.
</p>

<ul>
  <li>
    <h2>Heading Inside Bullet Level 1</h2>

    <p>
      Bullet paragraph with
      <strong>bold</strong>,
      <em>italic</em>,
      <u>underline</u>,
      <s>strikethrough</s>,
      <a href="https://example.com">link</a>,
      and <code>inline code</code>.
    </p>

    <blockquote>
      Quote inside bullet with
      <strong><em><s><u>
        <a href="https://example.com">
          <code>full styled code link</code>
        </a>
      </u></s></em></strong>.
    </blockquote>

    <ol>
      <li>
        Number Level 2 inside bullet

        <ul>
          <li>
            Bullet Level 3 inside number

            <ol>
              <li>
                Number Level 4 with
                <strong>bold</strong>,
                <em>italic</em>,
                <u>underline</u>,
                <s>strikethrough</s>,
                <a href="https://example.com">link</a>,
                and <code>code</code>.
              </li>

              <li>
                <strong><em><s><u>
                  <a href="https://example.com">
                    <code>Deepest Full Styled Code Link</code>
                  </a>
                </u></s></em></strong>
              </li>
            </ol>
          </li>

          <li>
            Back to Bullet Level 3
          </li>
        </ul>
      </li>

      <li>
        Back to Number Level 2
      </li>
    </ol>
  </li>

  <li>
    Back to Bullet Level 1
  </li>
</ul>

<!-- ALL TOOLBAR CONTROL COVERAGE -->

<p>
  Toolbar inline matrix:
  <strong>bold</strong>,
  <em>italic</em>,
  <u>underline</u>,
  <s>strikethrough</s>,
  <a href="https://example.com">link</a>,
  <code>inline code</code>,
  <strong><em><u><s>bold italic underline strikethrough</s></u></em></strong>,
  <a href="https://example.com"><code>code link</code></a>,
  <mention text="@Toolbar User" indicator="@" id="toolbar-user" type="user">@Toolbar User</mention>,
  and
  <mention text="#toolbar-channel" indicator="#" id="toolbar-channel" type="channel">#toolbar-channel</mention>.
</p>

<p>
  Full inline toolbar chain:
  <strong><em><u><s>
    <a href="https://example.com">
      <code>bold italic underline strikethrough code link</code>
    </a>
  </s></u></em></strong>
</p>

<!-- HEADING LEVEL AND INLINE STYLE MATRIX -->

<h1><strong><em><u><s>H1 full inline style</s></u></em></strong></h1>
<h2><a href="https://example.com">H2 linked heading</a></h2>
<h3><code>H3 code heading</code></h3>
<h4><strong><code>H4 bold code heading</code></strong></h4>
<h5><em><a href="https://example.com">H5 italic link heading</a></em></h5>
<h6><u><s>H6 underline strikethrough heading</s></u></h6>

<!-- ALIGNMENT MATRIX -->

<p style="text-align: left">
  Alignment left with <strong>bold</strong>, <code>code</code>, and
  <a href="https://example.com">link</a>.
</p>

<p style="text-align: center">
  Alignment center with <em>italic</em>, <u>underline</u>, and
  <mention text="@Center User" indicator="@" id="center-user" type="user">@Center User</mention>.
</p>

<p style="text-align: right">
  Alignment right with <s>strikethrough</s>,
  <mention text="#right-channel" indicator="#" id="right-channel" type="channel">#right-channel</mention>,
  and <code>inline code</code>.
</p>

<p style="text-align: justify">
  Alignment justify with enough text to wrap across more than one line on a
  phone. This checks that justified paragraphs keep inline code, links,
  underline, strikethrough, and mention spans in the expected places.
</p>

<h2 style="text-align: center">Centered H2 heading</h2>
<h3 style="text-align: right">Right aligned H3 heading</h3>

<!-- QUOTE SPLIT AND NESTED BLOCK MATRIX -->

<blockquote>
  Quote split one: plain quote paragraph.
</blockquote>

<blockquote>
  <h2>Quote split two heading</h2>
  <p>
    Quote paragraph with <strong>bold</strong>, <em>italic</em>,
    <u>underline</u>, <s>strikethrough</s>,
    <a href="https://example.com">link</a>, <code>inline code</code>,
    <mention text="@Quote User" indicator="@" id="quote-user" type="user">@Quote User</mention>,
    and
    <mention text="#quote-channel" indicator="#" id="quote-channel" type="channel">#quote-channel</mention>.
  </p>
</blockquote>

<blockquote>
  <ul>
    <li>Quote unordered item level 1</li>
    <li>
      Quote unordered item with nested ordered list
      <ol>
        <li>Quote ordered nested item</li>
        <li><code>Quote ordered nested code item</code></li>
      </ol>
    </li>
  </ul>
</blockquote>

<blockquote>
  <ol>
    <li>Quote ordered item level 1</li>
    <li>
      Quote ordered item with nested unordered list
      <ul>
        <li>Quote unordered nested item</li>
        <li><a href="https://example.com">Quote unordered nested link item</a></li>
      </ul>
    </li>
  </ol>
</blockquote>

<blockquote>
  <ul data-type="checkbox">
    <li checked>Checked checkbox inside quote</li>
    <li>Unchecked checkbox inside quote</li>
    <li checked><strong><code>Styled checked checkbox inside quote</code></strong></li>
  </ul>
</blockquote>

<blockquote>
  <pre><code>Quote code block
Line 2 inside quote code block
Line 3 inside quote code block</code></pre>
</blockquote>

<blockquote>
  <p>Quote image below:</p>
  <img src="https://reactnative.dev/img/tiny_logo.png" width="64" height="64" />
</blockquote>

<!-- LIST COMMAND MATRIX -->

<ul>
  <li>Unordered root item</li>
  <li>
    Unordered item with ordered child
    <ol>
      <li>Ordered child level 2</li>
      <li>
        Ordered child with unordered grandchild
        <ul>
          <li>Unordered grandchild level 3</li>
          <li><code>Unordered grandchild inline code</code></li>
        </ul>
      </li>
      <li>Back to ordered child level 2</li>
    </ol>
  </li>
  <li>Back to unordered root item</li>
</ul>

<ol>
  <li>Ordered root item</li>
  <li>
    Ordered item with unordered child
    <ul>
      <li>Unordered child level 2</li>
      <li>
        Unordered child with ordered grandchild
        <ol>
          <li>Ordered grandchild level 3</li>
          <li><a href="https://example.com">Ordered grandchild link</a></li>
        </ol>
      </li>
      <li>Back to unordered child level 2</li>
    </ul>
  </li>
  <li>Back to ordered root item</li>
</ol>

<ul data-type="checkbox">
  <li checked>Checkbox root checked</li>
  <li>
    Checkbox root unchecked with unordered child
    <ul>
      <li>Unordered child inside checkbox item</li>
      <li><strong>Bold unordered child inside checkbox item</strong></li>
    </ul>
  </li>
  <li checked>
    Checkbox root checked with ordered child
    <ol>
      <li>Ordered child inside checked checkbox item</li>
      <li><em>Italic ordered child inside checked checkbox item</em></li>
    </ol>
  </li>
  <li>Back to checkbox root unchecked</li>
</ul>

<!-- MEDIA, MENTION, AND CODE INTERACTION MATRIX -->

<p>
  Image between text:
  before image
  <img src="https://reactnative.dev/img/tiny_logo.png" width="48" height="48" />
  after image.
</p>

<p>
  Mentions with all inline styles:
  <strong><mention text="@Bold Mention" indicator="@" id="bold-mention" type="user">@Bold Mention</mention></strong>,
  <em><mention text="@Italic Mention" indicator="@" id="italic-mention" type="user">@Italic Mention</mention></em>,
  <u><mention text="#Underlined Mention" indicator="#" id="underlined-mention" type="channel">#Underlined Mention</mention></u>,
  and
  <s><mention text="#Struck Mention" indicator="#" id="struck-mention" type="channel">#Struck Mention</mention></s>.
</p>

<p>
  Inline code adjacency:
  <code>first code</code>
  normal text
  <code>second code</code>
  <a href="https://example.com"><code>linked code</code></a>
  trailing text.
</p>

<!-- BLOCKS INSIDE LIST ITEMS AND REVERSE NESTING -->

<ul>
  <li>
    Unordered item containing a quote
    <blockquote>
      Quote inside unordered list item with <strong>bold</strong>,
      <em>italic</em>, <u>underline</u>, <s>strikethrough</s>,
      <a href="https://example.com">link</a>, and <code>inline code</code>.
    </blockquote>
  </li>
  <li>
    Unordered item containing a heading
    <h3>Heading inside unordered list item</h3>
  </li>
  <li>
    Unordered item containing a code block
    <pre><code>Code block inside unordered item
Line 2 inside unordered item</code></pre>
  </li>
  <li>
    Unordered item containing an image
    <img src="https://reactnative.dev/img/tiny_logo.png" width="48" height="48" />
  </li>
  <li>
    Unordered item containing centered text
    <p style="text-align: center">Centered paragraph inside unordered item.</p>
  </li>
</ul>

<ol>
  <li>
    Ordered item containing a quote
    <blockquote>
      Quote inside ordered list item with
      <mention text="@Ordered Quote" indicator="@" id="ordered-quote" type="user">@Ordered Quote</mention>
      and
      <mention text="#ordered-quote" indicator="#" id="ordered-quote-channel" type="channel">#ordered-quote</mention>.
    </blockquote>
  </li>
  <li>
    Ordered item containing nested unordered list with quote
    <ul>
      <li>
        Nested unordered item before quote
        <blockquote>
          Quote inside nested unordered item inside ordered item.
        </blockquote>
      </li>
      <li>Nested unordered item after quote</li>
    </ul>
  </li>
  <li>
    Ordered item containing a right aligned paragraph
    <p style="text-align: right">Right aligned paragraph inside ordered item.</p>
  </li>
</ol>

<ul data-type="checkbox">
  <li checked>
    Checked checkbox item containing a quote
    <blockquote>
      Quote inside checked checkbox item with <code>inline code</code>.
    </blockquote>
  </li>
  <li>
    Unchecked checkbox item containing nested mixed lists
    <ol>
      <li>
        Ordered child inside checkbox item
        <blockquote>
          Quote inside ordered child inside checkbox item.
        </blockquote>
      </li>
      <li>
        Ordered child with unordered grandchild
        <ul>
          <li>
            Unordered grandchild with quote
            <blockquote>
              Deep quote inside checkbox, ordered, and unordered nesting.
            </blockquote>
          </li>
        </ul>
      </li>
    </ol>
  </li>
  <li checked>
    Checked checkbox item containing image and code block
    <img src="https://reactnative.dev/img/tiny_logo.png" width="48" height="48" />
    <pre><code>Checkbox item code block
Line 2 inside checkbox item</code></pre>
  </li>
</ul>

<blockquote>
  <p>Quote containing nested quote and mixed list blocks.</p>
  <blockquote>
    Nested quote inside quote.
  </blockquote>
  <ul>
    <li>
      List item inside quote containing another quote
      <blockquote>
        Quote inside list item inside quote.
      </blockquote>
    </li>
    <li>
      List item inside quote containing code block
      <pre><code>Code block inside list item inside quote
Line 2</code></pre>
    </li>
  </ul>
</blockquote>

<ul>
  <li>
    Complex list item with every nested block type
    <h4>Nested heading in complex list item</h4>
    <p>
      Paragraph in complex list item with <strong>bold</strong>,
      <em>italic</em>, <u>underline</u>, <s>strikethrough</s>,
      <a href="https://example.com">link</a>, <code>inline code</code>,
      <mention text="@Complex Item" indicator="@" id="complex-item" type="user">@Complex Item</mention>,
      and
      <mention text="#complex-item" indicator="#" id="complex-item-channel" type="channel">#complex-item</mention>.
    </p>
    <blockquote>
      Quote in complex list item.
    </blockquote>
    <ol>
      <li>Ordered child of complex list item</li>
      <li>
        Ordered child with checkbox list
        <ul data-type="checkbox">
          <li checked>Checked checkbox grandchild</li>
          <li>Unchecked checkbox grandchild</li>
        </ul>
      </li>
    </ol>
    <pre><code>Complex list item code block
Line 2 in complex list item</code></pre>
    <img src="https://reactnative.dev/img/tiny_logo.png" width="48" height="48" />
  </li>
</ul>

<pre><code>Standalone toolbar coverage code block
Line 2 keeps code-block spacing
Line 3 keeps code-block wrapping
Line 4 ends the block</code></pre>`;
