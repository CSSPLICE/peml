# Parsons Problem Input Format

First draft by Cliff Shaffer  
With help from:  
Steve Edwards, Barb Ericson, Seth Poulsen, and Kwasi Biritwum-Nyarko  
Last updated: 3/12/2025

[1\. Introduction](#introduction)

[2\. The Problem Preamble](#the-problem-preamble)

[3\. The Blocks Specification](#the-blocks-specification)

[4\. Order-based Grading](#order-based-grading)

[4.1 Simple DAG](#4.1-dag-grading)

[4.2 Simplified Notation](#4.2-simplified-notation)

[4.3 Nested DAGs](#4.3-nested-dags)

[5\. Execution-based Grading](#execution-based-grading)

[5.1 Preamble](#5.1-preamble)

[5.2 Tests](#5.2-tests)

[5.3 Reference Solution](#5.3-reference-solution)

[6\. Open Questions](#open-questions)

[7\. Change Log](#7.-change-log)

[8\. Obsolete Content](#8.-obsolete-content)

[8.1 Explicit DAGs](#8.1-explicit-dags)

## 

1. ## Introduction {#introduction}

The SPLICE Parsons Problem Input Format (PIF) is a slightly augmented version of [PEML](https://cssplice.org/peml/index.html) markup, which in turn derives from [ArchieML](https://archieml.org/). See examples for Parsons problems defined using PIF at: [https://github.com/CSSPLICE/peml-feasibility-examples/tree/main/parsons](https://github.com/CSSPLICE/peml-feasibility-examples/tree/main/parsons).

A note on vocabulary: In this document, the main content of a Parsons problem specification is a collection of *blocks*, which are the individual entities that a student arranges into some order (and possibly must modify in some way). Sometimes, multiple blocks need to be grouped together for some purpose. This is called a *block list*.

The operating assumption is that some Parsons problem implementation will read this file and interpret it as appropriate (or some translator will translate the PIF specification into the appropriate format used by the Parsons problem implementation). Not all Parsons problem implementations will be able to handle all features defined by PIF. Hopefully the system (or translator) will fail gracefully on such files.

The rest of this document contains a description of the major PEML tags that go into defining a Parsons problem. You can see a short list of these at [https://github.com/CSSPLICE/peml-feasibility-examples/blob/main/parsons/parsons-template.peml](https://github.com/CSSPLICE/peml-feasibility-examples/blob/main/parsons/parsons-template.peml).

PEML supports many keys not discussed in this specification. Generally they can be added for information purposes without harm, but PIF translators will typically ignore them.

Comments: Start with \# at the beginning of the line, and must be on lines by themselves.

The body of the problem specification is a series of key: value pairs. Note that PEML requires that all keys start at the beginning of the line (no indentation). PEML does allow indentation for complex value parts that naturally span multiple lines.

A PIF problem specification can be viewed as having three parts:

1. The PIF problem preamble, which consists of largely informational key:value pairs.  
2. The collection of blocks. In addition to specifying the blocks, it collectively embodies a DAG (or recursive DAG of DAGs) when grading is based on block order.  
3. Optionally, the necessary information for compiling and testing the code if the grading is done by execution.

2. ## The Problem Preamble {#the-problem-preamble}

exercise\_id: {Raw text string}  
**Required**. This is meant to be a unique identifier for the exercise within any given implementation system. It does not need to be human readable in any meaningful way. A popular choice is the link to the exercise source (the PIF file) in some repository.

title: {Text in Markdown format}  
**Required**. This should be human readable.

License block: **Required.** It consists of the following three key:value pairs.  
license.id: {A string from the [license keywords used by github](https://help.github.com/en/articles/licensing-a-repository)}  
license.owner.email: {Your email address}  
license.owner.name: {Your name}  
Technically, you can leave this out and most systems will be able to accept the problem specification. But we strongly encourage you to include this because nobody can safely use your exercise unless the file says that they can (and you can always explicitly deny use if you like). Thus, the PIF specification does officially require this.

settings block: **Required.** This structured object configures grading behavior and student interaction options. It replaces the former `tags.style` comma-separated string. The following keys are supported:

settings.grader.type: {order | execute}  
**Required**. Specifies the grading mode. `order` means the blocks must be arranged into a valid topological sort of the specified DAG. `execute` means the student's assembled code is executed against test cases.

settings.grader.show_feedback: {true | false}  
**Optional**. Whether to show per-block distractor feedback after grading. Defaults to `true`.

settings.indent.active: {true | false}  
**Optional**. Whether indentation is enabled for this exercise. If absent or `false`, blocks are not indentable and must not declare individual indent levels.

settings.indent.mode: {prescribed | free}  
**Required when indent.active is true**. `prescribed` means each block declares its required indent level in the PIF file, and the grader enforces it. `free` means the student sets indentation freely in the UI; no per-block indent levels are declared or enforced.

settings.indent.max_indents: {number}  
**Optional**. The maximum number of indent levels available to the student. Defaults to `3`. Ignored when `indent.active` is false.

settings.adaptive: {true | false}  
**Optional**. Whether hint-based adaptive mode is enabled. Defaults to `true`.

settings.numbered: {true | false}  
**Optional**. When `true`, blocks are displayed with position numbers.

tags.topics: {Whatever keywords you want}  
**Optional.** This lets you describe the problem topics.

tags.interface\_layout: {horizontal | vertical}  
**Optional:** Most implementations have an area that contains the initial list of blocks, and an area where blocks are placed to construct the answer. This tag lets the problem author recommend to the system whether those should be placed side-by-side (horizontally) or one above the other (vertically).

instructions:----------  
Put here whatever text that you want students to see preceding the blocks.  
\----------  
**Required**. Uses Git-flavored Markdown input, with LaTeX notation to support math. May use multiple lines. The \---------- line ends the instructions.

\[systems\]  
language: \<Your programming language\>  
\[\]  
**Required** for execute-style problems, **optional** for order-based grading. Note that the language key is an element of the \[systems\] array, as indicated here (if language is not being specified, then there is no need to indicate a \[systems\] array if it is not otherwise being used). Whenever the language is specified, the presentation system can use this value to determine formatting and syntax highlighting (which is why the author might choose to define language for an exercise that is graded by block order). Be careful what you put in for the programming language. The string has to be recognizable by the system that implements the problem. This is usually a specific list of possible keywords, and case might matter.

3. ## The Blocks Specification {#the-blocks-specification}

The heart of any Parsons problem is the blocks that the student will manipulate into some order (possibly along with fixed text portions that appear at appropriate places, which are just some special blocks). In PIF, the block list defined as a hashmap on assets.code.blocks containing a (possibly nested) array of blocks along with various descriptors. The general format would be:

assets.code.blocks.\<key\>: \<value\> {Repeat as needed for various keys}  
\[assets.code.blocks.content\]  
{Put your blocks here}  
\[\]

Notice the syntax for PEML arrays:  
\[key-name\]  
{stuff: typically a series of key: value pairs, or possibly sub-arrays}  
\[\]

Each block has a series of key:value pairs, only one of which is required: The display key followed by the block text. Blocks commonly also have an optional blockid tag whose value is a simple alphanumeric string. Generally good practice is that either every block has a blockid tag, or none do (see [Section 4 Order-based Grading](#order-based-grading)).

It is a restriction of the underlying PEML notation syntax that every block start with the same key (nearly always this would either be the blockid if these are used, or display if blockid is not used).

Here is a simple example:

\[assets.code.blocks.content\]  
blockid: one  
display: print('Hello')

blockid: two  
display: print('Parsons')

blockid: three  
display: print('Problems\!')  
\[\]

Following PEML standard notation, any block can be defined to span multiple lines, as delimited by \---------- (or delimited by any other symbol repeated at least three times).

blockid: starter  
display:----------  
public static void Swap(int\[\] arr, int i, int j)  
{  
\----------

**Fixed blocks:** The blockid can take the special keyword fixed. A "fixed" block contains text that appears fixed in the student solution, and cannot be manipulated. This lets the problem developer specify things like framing code around the solution, fixed lines of code within the solution that offset subsections of blocks, or sub-section descriptions for things like proofs. Problem authors should be aware that not all implementations have the ability to support fixed blocks. Here is an example showing how the two lines of starter code for a method could be shown as a fixed block (that presumably comes at the beginning of the blocks list).

blockid: fixed  
display:----------  
public static void Swap(int\[\] arr, int i, int j)  
{  
\----------

In the list of blocks for a problem, some might be fixed and some not fixed. Any that appear in the list between two fixed blocks are meant to appear between those fixed blocks in the solution (but which might be displayed in random order between those fixed blocks). For example:

\[assets.code.blocks.content\]  
blockid: fixed  
display: Fixed Start

blockid: randomg1b1  
display: Random Group 1 Block 1

blockid: randomg1b2  
display: Random Group 1 Block 2

blockid: randomg1b3  
display: Random Group 1 Block 3

blockid: fixed  
display: Fixed Middle

blockid: randomg2b1  
display: Random Group 2 Block 1

blockid: randomg2b2  
display: Random Group 2 Block 2

blockid: randomg1b3  
display: Random Group 2 Block 3

blockid: fixed  
display: Fixed End  
\[\]

In the above example there is a fixed block that displays "Fixed Start", followed by three blocks that should appear in the solution in some order (they can be displayed in random order to the student), followed by a fixed block that displays "Fixed Middle", followed by three more blocks that should appear in the solution in some order after the "Fixed Middle" block (they can be displayed in random order to the student), and finally a fixed block that displays "Fixed End".

The display field is generally text in Git-flavored Markdown format that indicates what is displayed to the student for that block. This means that things like math can easily be added. Note that execute\-style problems should only have display text that is actual code in the associated programming language (or use a code field to replace the displayed text as described below). Here is an example of using math styling in a simple proof exercise.

\[assets.code.blocks.content\]  
blockid: one  
display: Assume $A \\land B \\land C$.

blockid: two  
display: Then $A$ is true.

blockid: three  
display: Then $C$ is true.

blockid: four  
display: Since $A$ and $C$, we know $A \\land C$.  
\[\]

Blocks specifications can be more complicated. For problems that require specific indentation be indicated by the student, the required indentation level can be specified by the indent key. For "pseudo-code" exercises (where the code to be executed for a block is different from the display text for that block), the executable code can be specified by the code field. For any problem with execute grading, any block where the code field is absent uses the display field string for its code. Here is an example that uses indent and code fields in block specifications. Note that in this example, the displayed lines appear to the student as Java code, but the actual executable will be in Python.

\[assets.code.blocks.content\]  
blockid: one  
display: for (int i=0;i\<3;i++) {  
code: for i in range(3):  
indent: 0

blockid: twoindent  
display: System.out.print("I ");  
code: print('I ', end='')  
indent: 1

blockid: three  
display: System.out.print("am ");  
code: print('am ', end='')  
indent: 1

blockid: four  
display: System.out.print("a Java program ");  
code: print('a Java program ', end='')  
indent: 1

blockid: five  
display: }  
code:  
indent: 0  
\[\]

Note that when `settings.indent.mode` is `prescribed` (typically paired with order-based grading), the indent value on each block specifies the required indentation level for that block, and the grader enforces it. When `settings.indent.mode` is `free` (common with execution-based grading in indentation-sensitive languages like Python), `settings.indent.active` informs the implementation that students must be able to set indentation levels, but the per-block indent key is not used and any block-level indent declarations are ignored by the grader. The indent property is never needed for distractor blocks. If `settings.indent.active` is `true`, the `settings.indent.mode` must also be set.

**Reusable blocks:** Usually a block can be used only one time in the solution, and a typical implementation will remove it from the source area when the student drags it to the solution area. However, sometimes the author might want to allow a block to be used more than once. For example, there might be a need for three closing braces to indicate completing nested blocks. Instead of providing three such blocks explicitly (with potential confusion about which instance of the same display text is which in the solution), the block can be marked as "reusable". If the block is indentable, then different uses of the block might have different indent levels. Reusable blocks can only be used with execute grading (because there is no reasonable way to indicate all the constraints required for reusable blocks in order grading). Here is an example:

blockid: MyReusableBlock  
reusable: true  
display: }

**Toggles and text boxes:** Blocks can contain toggle boxes (places where the student has to select one of a fixed number of options) or text boxes (places where the student has to type in code). The toggle or text box is delimited by two instances of a single-character delimiter symbol. The default delimiter symbol is \`, but this can be changed. In the case of a toggle, the individual choices are delimited by a single instance of the delimiter symbol. A textbox is indicated by four instances of the delimiter symbol (like: \`\`\`\`). If there is only one choice given, then it is treated as a textbox with initial code (that presumably needs to be modified by the student). Toggles and textboxes only make sense in the context of the execute grading option.

Examples:

blockid: mytoggle1  
display: if \`\`a\`b\`c\`\` \`\`\<\`\>\`\>=\`\` b

Here, there are two separate toggle boxes. First the student chooses between a, b, and c. Then the student chooses between \<, \>, and \>=. (Assume that the goal is to reach if a \< b).

blockid: mytextbox1  
display: if a \`\`\`\` b

Here, the student has to type something between a and b, with no prompt on the choices. (Again, assume the goal is to reach  if a \< b).

blockid: mybuggyblock  
display: if a \`\`\<\>\`\` b

 Here, the student must replace \<\> with whatever they think is correct. (In this case, if the goal is to reach if a \< b, then they would just edit to get rid of the \> character).

The delimiter symbol can be changed in either of two ways. If the author wants to change it for a particular block, then the optional delimiter tag is added, such as:

blockid: mytoggle1  
delimiter: \\  
display: if \\\\a\\b\\c\\\\ \\\\\<\\\>\\\>=\\\\ b

Alternatively, the author can change the default for the entire problem specification by adding the delimiter definition as a key of the assets.code.blocks object, as follows:

assets.code.blocks.delimiter: \\  
\[assets.code.blocks.content\]  
{Put your blocks here}  
\[\]

**Block lists:** There are a number of reasons why a collection of blocks might need to be grouped together. Grouping blocks can help with specifying restrictions on block order when grading; with indicating distractor blocks; or with controlling block layout in the interface. By default, the full list of blocks is considered a block list. But authors can specify sub-lists of blocks and define appropriate properties. Note that a block defined to be a block list does not have a display key.

\[assets.code.blocks.content\]  
blockid: myblocklist  
\[.blocklist\]  
\<subblock1\>

\<subblock2\>  
\[\]

\<the-next-block\>  
\[\]

**Block list layout:** Any block list can use the layout key to specify whether its layout should be horizontal or vertical. Since this can apply to any block list, this means that the implementation system can be prompted to show all blocks horizontally, or only a sublist of blocks. The most typical use case is a single horizontal list of blocks, such as for describing a problem to write a Regular Expression. The syntax for a problem to create a RegEx with an arbitrary number of a's followed by an arbitrary number of b's might look like this:

Assets.code.blocks.layout: horizontal  
\[assets.code.blocks.content\]  
blockid: B1  
display: a

blockid: B2  
display: \*

blockid: B3  
display: b

blockid: B4  
display: \*  
\[\]

**Pick-ones (grouped distractors):** A special type of block list has the key value pickone. Only one of the grouped blocks (the first one in the list) should be selected in the final solution. Ideally the exercise implementation system would indicate to students that they should pick exactly one of the grouped blocks, though that is not a strict requirement. Here is an example of pick-one blocks. Note that the pickone tag is set to true. 

blockid: mygroup\_name  
depends: whatever  
pickone: true  
picklimit: 1  
\[.blocklist\]  
blockid: one  
display: int temp \= arr\[i\];

blockid: onedistract1  
display: int temp \= arr\[j\];

Blockide: onedistract2  
Display: int temp \= arr\[l\];  
\[\]

The picklimit tag is optional. This indicates the number of distractors that should be displayed (selected at random from the distractor blocks if there are more distractors than are meant to be displayed).

PIF supports any number of distractors in the pick-one block list. However, exercise authors should recognize that any given implementation might handle this in different ways. Some implementations have no such concept, and so the distractor block(s) might appear anywhere in the randomized blocklist. Other implementations only have the concept of paired distractors (a correct block and a single associated distractor block). In which case, the implementation might choose to ignore additional distractor blocks in the pick-one list.

**Distractor Feedback:** Distractor blocks can have feedback text associated with them, such that if the block appears in the student answer, that text is intended to be displayed in proximity to it when the exercise is evaluated and feedback is presented. Examples:

blockid: pickone1  
pickone: true  
\[.blocklist\]

blockid: one  
display: int temp \= arr\[i\];

blockid: onea  
display: int temp \= arr\[j\];  
feedback: This was the wrong choice.  
\[\]											

blockid: four  
display: int temp \= arr\[j\];  
feedback: This line should not appear in the answer.

**Starter code**: Sometimes the author would like for the blocks to be presented within a framing context, such as a function header at the top, a closing bracket at the bottom, and the moveable blocks in between. This could be implemented with fixed blocks. But as a convenience, this can instead be implemented using PEML standard notation for starter code. It typically looks as follows.

\[assets.code.starter.files\]  
content:----------  
public ArrayList\<Integer\> reverseContents(int\[\] contents) {  
    \_\_\_  
}  
\----------

In this example, \_\_\_ is used to mark where the blocks in the blocks list will appear, with immovable code above and below.

4. ## Order-based Grading {#order-based-grading}

### 4.1 DAG Grading {#4.1-dag-grading}

When `settings.grader.type` is `order`, a DAG is **required** to be specified implicitly, typically by the use of depends tags in the various blocks. Any student-submitted solution is expressed to the grader as an ordered list of blocks, and it is accepted as correct if it is a legal topological sort for the DAG.

A depends tag can have an empty value. This indicates that the block is the (or, a) root of the DAG. (Note that a depends tag with an empty value is different from a block with no depends tag. See the next section about simplified notation for when a depends tag can be omitted.)

Consider a simple example that includes a distractor and some choices on the acceptable ordering of the blocks in the student's solution. In the figure, the strings are block IDs.

The image on the left shows the relationship in the blocks as specified (arrows point to parents in the DAG, which are blocks that the block explicitly depends on). The version on the right shows the actual DAG to be processed (arrows are reversed). In both versions, block onea is crossed out since it is a distractor, and so does not participate in the DAG. In this example, there are two acceptable solutions since there are two legal topological sorts of the DAG.

* one two three four  
* one three two four

Being a distractor, Block  onea is not part of any solution.

The block definitions specify their relationship within the DAG by specifying their direct dependencies with the depends tag. The example DAG above could be written using the following depends tag values. In the example, a pickone group is used. This is not actually required, these could just be independent blocks with one of them having \-1 as its dependency to indicate that it cannot appear in any solution. The advantage of putting them together as a pickone list is that the implementation interface now has enough information to indicate that only one of those two should be picked if it chooses to provide that information to the student.

\[assets.code.blocks.content\]

blockid: pickone1  
pickone: true  
\[.blocklist\]  
blockid: one  
display: good  
depends:

blockid: onea  
display: not so good  
depends: \-1  
\[\]											

blockid: two  
display: block 2  
depends: one

blockid: three  
display: block 3  
depends: one

blockid: four  
display: block 4  
depends: two, three  
\[\]

### 4.2 Simplified Notation {#4.2-simplified-notation}

The depends tag is optional. If a block does not have a depends tag, then the block is dependent on the first preceding block that is not a distractor (that is, does not have \-1 for its own depends value). This allows for a simpler way to present a single-order list of blocks. If the first block on the list has no depends tag, then it is the (or, a) root of the DAG. If the preceding block is a distractor, then that is ignored and the first non-distractor block preceding that is the actual dependency for the block.

Since the blockid tag is optional, a block can only be a depends target for another block if it has a blockid tag, or if the block that immediately follows has no explicit depends tag.

Here is an example of a minimalist set of information for the case when the block ordering is just the blocks as given, with a distractor thrown in.

\[assets.code.blocks.content\]  
display: print('Hello')

display: print('Parsons')

display: print('Oops\!')  
depends: \-1

display: print('Problems\!')  
\[\]

The only acceptable solution for this example would be:

print('Hello')  
print('Parsons')  
print('Problems\!')

### 4.3 Nested DAGs {#4.3-nested-dags}

A simple DAG is not always sufficient for specifying the possible legal orders. Here is a simple example:

if (atest) {  
  doAstuff();  
}  
if (btest) {  
  doBstuff();  
}  
if (ctest) {  
  doCstuff();  
}

In this example, the three cases are independent and can be done in any order, but the code inside the "if" block has to go with the proper "if" test. This can be indicated by using a DAG of DAGs. The sub-DAGs are indicated by using block sublists.

\[assets.code.blocks.content\]  
blockid: testAblock  
depends:  
\[.blocklist\]  
blockid: caseA  
display: if (testA) {  
depends:

blockid: stuffA  
display:----------  
  doAstuff();  
}  
\----------  
depends: caseA  
\[\]

blockid: testBblock  
depends:  
\[.blocklist\]  
blockid: caseB  
display: if (testB) {  
depends:

blockid: stuffB  
display:----------  
  doBstuff();  
}  
\----------  
depends: caseB  
\[\]

blockid: testCblock  
depends:  
\[.blocklist\]  
blockid: caseC  
display: if (testC) {  
depends:

blockid: stuffC  
display:----------  
  doCstuff();  
}  
\----------  
depends: caseC  
\[\]

Note that a block sublist (i.e., a nested DAG) is considered to be a block in all respects (with the exception that it has no display key), especially in terms of how it behaves for the purposes of order-based grading. It generally should have a depends tag to indicate how it should be ordered (if it is missing, then it is assumed to depend on the preceding non-distractor block). Blocks may not have depends values with tags within another block sublist, either above it (that is, outside this block list) or below it (that is, within a block list that is within the current block list).

5. ## Execution-based Grading {#execution-based-grading}

### 5.1 Preamble {#5.1-preamble}

When `settings.grader.type` is `execute`, this is how you specify the context of how to place the code built from the student's blocks, and the test cases or required output.

The programming language to be used for execution must be specified with a language tag within the \[systems\] block (see Section 2).

Sometimes you have "wrapper code" that should be used when executing the solution, but which the student should not see, specified as in this example:

\[assets.code.wrapper.files\]  
content:----------  
public class StringProblem  
{  
   \_\_\_  
}  
\----------  
\[\]

In the example, the last set of dashes signals the end of the content block. The set of underscores inside the brackets signals where the student code will go.

### 5.2 Tests {#5.2-tests}

When the coding exercise is to create a method with specified inputs and outputs, the best way to test is by providing unit tests in the following format.

\[assets.test.files\]  
format: text/csv-unquoted  
pattern\_actual: subject.compressString({{message}})  
content:----------  
message,expected,description  
"""bbbaaccccd""","""b3a2c4d1""",example  
"""abccdeff""","""abccdeff""",example  
"""a""","""a"""  
"""abb""","""abb"""  
"""aaacdddaaa""","""a3c1d3a3"""  
"""aabcbbbb""","""a2b1c1b4"""  
\----------  
\[\]

In this example, it is assumed that the student is told to write a method called compressString that takes a string parameter and returns a string. (This would probably be done either by describing this requirement in the instructions and providing appropriate blocks that allow the student to specify the method signature, or by supplying fixed blocks to define the method signature.) Note the first line after the start of the content block in this example specifies the format of the tests. In this case, message is the input parameter (it was defined in the pattern\_actual value field), expected is a special keyword to indicate the output value, and description is a special keyword that indicates an (optional) parameter that indicates whether the test case is exposed or hidden from the student when the exercise is graded.

TODO: Show what to do when the exercise is not a method with unit tests, but instead the validation is done by checking a single, static value for the output.

### 5.3 Reference Solution {#5.3-reference-solution}

Exercise authors may include an optional section with a reference solution. One reason to provide this is because the implementing system might be able to execute this over the test cases as a way to cross-validate the two.

Following standard PEML format, the reference solution is specified as follows.

TODO: Show PEML format for reference solution.

6. ## Open Questions {#open-questions}

1. What should this be called? I had previously assumed that the community consensus was that the term "Parsons problem" could be applied to any block reordering problem. But not everyone uses the term this way, some limiting it to only coding problems. What term should we use? Stick with Parsons problems? Or call it something else? (If so, the specification should say in appropriate places that this includes Parsons problems as a subset.)  
2. How can we handle blocks with "holes" in them for placing other blocks? There might be constraints on which blocks can fill in the holes, or any available blocks might be fair game. An example use case might be code for the start and the end of a method (which might even be fixed code). This might be handled with two separate blocks, but the interface might want to indicate that they are linked in some way.  
3. As currently written, specific context usage features (things not intrinsic to an exercise definition, but rather that depend on how the exercise is to be used) are deliberately left out of the spec. The idea here is that context would be given to the implementation system as part of system authoring and use of exercises, not as part of the PIF definition. But perhaps this is inconvenient to actual use. An alternative is to put tags into PIF that allow problem authors (or instructors modifying a problem definition for use in a given course) to specify these contextual features. So far, these features have been identified as falling into this category:  
   1. Block numbering  
   2. A fixed order given to all users of the exercise (which ideally is generated randomly, but identically to all users)  
   3. The relative relationship between the drop zone for constructing the solution, and the block pool. They could reasonably be side-by-side, or one above the other.  
   4. First Wrong: (For order-based grading) Indicate to the student the first block recognized by the system to be wrong in some way (that is, it violates the required dependencies).

## 7\. Change Log {#7.-change-log}

1/2/2025: Added support for a "simplified" presentation, by making tag and depends fields optional (with default behavior when they are missing).  
3/12/2025: Ditched the notion of an explicit DAG section.  
4/8/2025: Changed the blocks list to be an array belonging to \[assets.code.blocks\] rather than be part of \[assets.code.starter.files\].  
4/9/2025: Simplify the syntax for block lists and decorator keys; clean up pickone syntax (it is just a blocklist with a pickone: true key)  
5/5/2025: Replaced `tags.style: parsons, {order|execute}, <indent>` and standalone `numbered` with a structured top-level `settings` object.

## 8\. Obsolete Content {#8.-obsolete-content}

OBSOLETE, LEFT FOR NOW UNTIL DETAILS ARE ALL RESOLVED: PIF is agnostic on as many implementation-dependent things as possible, like whether blocks of code are presented in a particular way such as with a mono-spaced font. (Of course, PIF does supply enough information so that an implementation can deduce whether the blocks contain code or not. Note that not all Parsons problems are meant to be coding exercises. For example, they might be math proofs.) PIF is agnostic on how the implementation system handles fixed blocks (these are blocks that are not ones that the student has to select and place, but are fixed in the solution). PIF does not provide a way to dictate that all copies of the problem (to different students) provide the same random ordering, since again this is considered an issue for how the problem is **presented**. Anything that relates to presentation as opposed to intrinsic property should get handled by the authoring system associated with the local system implementation.

### 8.1 Explicit DAGs {#8.1-explicit-dags}

Open Question: Previously, the DAG was defined in a separate section from the block specification. Support is now added to define the DAG implicitly by adding depends fields to the individual blocks. If this is considered clearly superior, we could just drop the support for the explicit version in the \[assets.test.files\] section.

After discussion at the 11th SPLICE Workshop (at SIGCSE 2025), participants agreed to drop the explicit DAG support from PIF.

Basic example:

#### Method 1: Explicit DAG Definition

The tag \[assets.test.files\] is a PEML specification for an array of objects. There is   
only one item for this array: the content. This in turn is a list of blockids, with the blockids for dependency blocks listed. If a given block is a distractor, then its depends tag has the special blockid value \-1.

\[assets.test.files\]  
Content:----------  
\# A series of lines where each line has the format:  
\<blockid\>: \<zero or more comma-separated dependency blockids\>  
\----------  
\[\]

Here is an example:  
\[assets.test.files\]  
content:----------  
one:  
onea: \-1  
two: one  
three: one  
four: two, three  
\----------  
\[\]

Explicit nested DAG example:

\[assets.code.blocks.content\]  
blockid: caseA  
display: if (testA) {

blockid: stuffA  
display:----------  
  doAstuff();  
}  
\----------

blockid: caseB  
display: if (testB) {

blockid: stuffB  
display:----------  
  doBstuff();  
}  
\----------

blockid: caseC  
display: if (testC) {

blockid: stuffC  
display:----------  
  doCstuff();  
}  
\----------  
\[\]

\# Specify the nested DAG.  
\# This defines three sub-dags, all of which have no listed  
\# dependencies (meaning their roots have no prereqs, so they can go  
\# in any order).  
\[assets.test.files\]  
content:----------  
\[DAG\]  
caseA:  
stuffA: caseA  
\[\]  
\[DAG\]  
caseB:  
stuffA: caseB  
\[\]  
\[DAG\]  
caseC:  
stuffA: caseC  
\[\]  
\----------  
\[\]
