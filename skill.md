# What is Sparky test

Sparky tests allows to test Rocky Linux configurations and installation by using Raku as high level scenario
and tasks written on Bash. 

High level Raku scenario is just a list of tasks, keep it simple:

***main.raku***

```raku
task-run "tasks/prepare";
task-run "tasks/install";
task-run "task/check-install";
```

The scenario should be named "main.raku", every task-run function accepts path to directory
where file "task.bash" should be located. The scenario above just calls three separate tasks
executed one by one.

**tasks/prepare/task.bash**

```bash
set -e
echo "prepare install"
```

**tasks/install/task.bash**

```bash
set -e
sudo dnf update -y
dnf install -y nginx
```

**tasks/check-install/task.bash**

```bash
set -e
curl -f  http://127.0.0.1
```

In other words - tasks.bash is regular Bash script where you can do anything a user would to
install or configure Rocky Linux. In this example one installs nginx. For readably and better
code management one can split big scenario into many tasks and call those tasks from "main.raku"
file using task-run function.


Tasks best practices

* Add `set -e` in the beginning of every task to ensure that task fails fast at the very first error

* Sometimes it's reasonable to add tasks checks when having zero exit code is not enough to ensure test success

* Always make it sure run commands in unattended mode by supplying relevant command line parameters, for example
adding `-y` option will force running dnf install without waiting confirmation from a user:


```bash
dnf install -y nginx
```

# Task checks


Task checks are optional they allow to test tasks stdout adding extra testing capabilities when it's
not enough to rely Bash script exit code to ensure that a test succeeds.

To add task check simple create task.check file in the same directory where task.bash resides

***tasks/check-install/task.bash***

```
Welcome to nginx
```

This task check ensures the curl command used in task.bash emits proper message from Nginx web server


# Task check comprehensive guideline

Following is complete guideline for task check language, use it to create task check of arbitrary complexity

---

## Task Check DSL

* Is a domain specific language to parse and verify _arbitrary_ text

* TC stands for Task Check, TC language is a Task Check Language

## Task check files

Task check DSL code should be written and saved into task.check file

In this tutorial whenever DSL term is uses  it means the content of task.check file

### Declarative way

Static rules - check expressions - that define verification.

### Imperative way

* Dynamically generated rules - check expressions - are generated in _runtime_ by using DSL compatible programming languages

* DSL compatible programming languages (Perl/Bash/Python/Ruby/Raku) - see examples

Sparrow6 provides an API implemented for compatible languages (see `matched()`, `captures()`, `streams_array()` functions)

Most of examples below will be for Perl5, but the same applies for other compatible languages. 

## DSL parser aka task checks parser

DSL parser is the program which:

* parses DSL code

* parses input data

* verifies input data ( line by line ) against check expressions ( line by line )

## Verification process

Verification process matches lines of input text against check expressions.

This is rough explanation of the algorithm:

* For every _check expression_ in a check expressions list:
  * Calculate current _search context_
  * Set the _check step_ status as `unknown`
  * For every _line_ in input text:
    * Calculate if the line matches _check expression_
    * If line matches then marks check step status as `succeeded` 
    * Next line
  * End of lines loop
* If the check step status is `unknown`, then set check step status to `failed`
* Next check expression
* End of expressions loop

* Check if all check steps succeeded. 
* If all check steps succeeded then the overall check status is `success` otherwise is `failed`

## Search context

Verification process is taken in a _context_.

By default search context _is an original_ input text stream, which is also called default search context.

However search context could be changed by applying search context modifiers ( see sequence and range expressions ).

When search context gets applied _effective_ search context narrows down depending on search context logic. 

Search context is restored to default one every time when DSL parser meets `end:` marker,  see also sequence and range  expressions.


# Check expressions pitfalls

If a check expression check fails it does not terminate the whole scenario straight away, the failed checks is marked in internal state and will result in whole scenario failure when scenario is finished.

So it's wrong to assume if we reach the end of task.check there is no check failures

In other words even though a check is failed parser mark it state as failed and goes to the next check

# Plain text expressions 

Plain text expressions are plain strings to match against input text:

DSL:

    This text should be here
    
Plain text expressions are case sensitive:

Input:

    I am OK

DSL:

    I am OK
    I am ok


# Regular expressions

Similarly to plain text matching, one may check against regular expressions.

The TC language uses [Raku Regular Expressions](https://docs.raku.org/language/regexes).

WARNING!!!

Raku regular expressions are quite different
from Perl regexps, please refer the documentation - https://docs.raku.org/language/regexes to correctly write them

Example:

Input

    2019-04-01
    Name: Sparrow6
    App Version Number: 0.0.1

DSL

    regexp: \d\d\d\d "-" \d\d "-" \d\d # date in format of YYYY-MM-DD
    regexp: "Name:" \s+ \w+ # name
    regexp: "App Version Number:" \s+ \d+ "." \d+ "." \d+ # version number
    
## Matching multiline strings

Check expressions match text in _line by line_ ( aka single line ) mode, there is no way 
to match multiline strings ( but see sequence expressions ).
    
For instance following check fails, even though regular expression is correct:

Input:

    A
    B
    
DSL:

    regexp: A \n B

But you can match consecutive series of lines using sequence expressions.

## Regular expressions pitfalls

- Raku regular expressions are quite different from Perl regexps, please refer the documentation - https://docs.raku.org/language/regexes to correctly write them

- Multiline regular expressions ( unlike in Raku ) are prohibited. Following example of DSL is incorrect:

```
regexp: \d
\s
\d
```

This is correct form:

```
regexp: \d \s \d
```

If you need to write lengthy regular expression that does not fit your editor 
screen width, you can use generator: to split
the expression by smaller chunks and generate
final expression dynamically using one of
the supported programming languages

## Following is quick migration guide from Perl to Raku regexps

- Spaces

In Raku spaces act differently then in Perl regexps. 

1) If you want to check against spaces you either use `\s+` or `" "`. 

Examples:

```
regexp: \s
# next regexp is equivalent to the previous one
regexp: " "

# also following two expressions
# are equivalent
regexp: "Hello World"
regexp: "Hello" \s "World"
```

2) we use spaces to separate chunks in complex regexp for *readability*, they never treated as spaces unless they are quoted  (see point number 1), for example:

```
regexp: "Bla" "Bla" \d
```

will match "BlaBla100" string

- Quotes for alpha numeric strings

You don't need quotes for letters and numbers unless there is a space needed to match (see the spaces section):

```
# this all works without quotes

regexp: Hello 
regexp: ABC
regexp: 1977
```

Adding quotes for those elements, changes nothing, but readability.

Thus following expressions will do the same as the previous ones:

```
regexp: "Hello"
regexp: "ABC"
regexp: "1977"
```

- Special symbols

Symbols `~ : , @ * . ! | / \ - " ' $ [ ] ( ) + = ^ ?`  have special meaning unless they are quoted or escaped, so to match "Hello:"

```
regexp: "Hello:"
```

- Digits

```
note: 4 digits should be in stdout
regexp: \d\d\d\d
```

- Digits and symbols

```
# match "Hello world"
# followed by date 
# in format MON.DD.YYYY
# where MON - month identified as 3 symbols
# for example JAN.01.2025

regexp: "Hello world" \s <[A..Z>]> ** 3 "." \d\d "." \d\d\d\d 
```

- Mixing quotes and back slashes

When escaping symbols ,.+-:,= choose either
quote or back slash, but not both for readability:

```
# legit, but not necessary
# to use both \ and " for
# escaping of .
regexp: "\.hello"

# following two expressions
# do the same:

# escaping by back slash
regexp: \.hello

# escaping by quotes
regexp: ".hello"

```
- Zero or more symbols

```
# 0 or more A
regexp: A*
```

- One or more symbols

```
# One or more A
regexp: A+
```

- Strictly N symbols

```
# only four A
regexp: A ** 4
```

```
# From two to four A
regexp: A ** 2..4
```

- Any symbol, no symbols at all

```
# you can use regexp form:
regexp: .*
# or this form:
:any:
```

- Beginning of string 

Use `^^` for beginning:

```
regexp: ^^ "Here we begin"

# or with zero or many
# leading spaces

regexp: ^^ \s* "Look ma at my tabs"

```

- End of string

Use `$$` for end of string:

```
regexp: "wait until the end" \s* $$
```

See also https://docs.raku.org/language/regexes#Quantifiers

- Symbol ranges

Instead of writing `[a-z]` like in Perl, use this form:

```
# anything from a to z
regexp: <[a..z]>
```

```
# anything from a to z, repeated 3 times
regexp: <[a..z]> ** 3
```

See also https://docs.raku.org/language/regexes#Enumerated_character_classes_and_ranges

- Alternations

Alternations allows to match from many possible options:

```
# should be at least something
# out of three colors:
regexp: red || green || blue
```

To separate alternations from other regexp terms use square brackets:

```
regexp: "hello, mister" \s [ Red || Green || Brown ] "," \s "would you like a" \s [ tea || coffee ] "?"
```

See also [Alternations](https://docs.raku.org/language/regexes#Alternation:_||)


## Matched data and capturing

* Parser matches all the lines of input text against check expression

* If at least _one line_ matches a check expression - check step is considered as successful

* Matched lines are captured and accumulated inside @matched array and available through `matched()` function, see https://github.com/melezhik/Sparrow6/blob/master/documentation/development.md

* If regular expressions with [capturing](https://docs.raku.org/language/regexes#Capturing) are used, 
the respected captures get _accumulated_ inside `@captures` array and available through `captures()` function, see https://github.com/melezhik/Sparrow6/blob/master/documentation/development.md

* Layer is captures for a single check step, see also streams

Examples:

Input:

    1 - for one
    2 - for two
    3 - for three

DSL:

    regexp: (\d+) \s+ '-' \s+ for \s+ (\w+)
    
    code: <<CODE
    !perl
    
    use Data::Dumper; 
    
    print Dumper(captures());
    
    CODE
    
Output:

    [task check]
    <(\d+) \s+ '-' \s+ for \s+ (\w+)> True
    $VAR1 = [
              [
                '1',
                'one'
              ],
              [
                '2',
                'two'
              ],
              [
                '3',
                'three'
              ]
            ];
    

Likewise `matched()` function return array of matched lines:

For the same input:

DSL:

    regexp: \d
    
    code: <<CODE
    !perl
    
    use Data::Dumper; 
    
    print Dumper(matched());
    
    CODE
    
Output:

    [task check]
    <\d> True
    $VAR1 = [
              '1 one',
              '2 two',
              '3 three'
            ];
    
The difference between `matched` and `captures()` is that `matched()` returns array of matched lines, while
`captures()` returns array of _captured_ variables for _every_ matched line ( that means array of arrays ),
_if_ regular expression has [capturing](https://docs.raku.org/language/regexes#Capturing);

In case there is no capturing in regular expression or plain strings check used `captures()` is equivalent of `matched()`

`capture()` function returns first element of the `captures()` array.

You can do more with captured data then just dumping it out. One of the common cases is to _compare_ captures
with certain values, using _asserts_. Add this code to the previous example:

DSL:

    generator: <<CODE
    !perl
    print "assert: ", captures()->[0]->[0] == 1 ? 1 : 0, " captures0,0 == 1\n";
    print "assert: ", captures()->[0]->[1] eq 'one' ? 1 : 0, " captures0,1 == one\n";
    
    print "assert: ", captures()->[1]->[0] == 2 ? 1 : 0, " captures1,0 == 2\n";
    print "assert: ", captures()->[1]->[1] eq 'two' ? 1 : 0, " captures1,1 == two\n";
    
    print "assert: ", captures()->[2]->[0] == 3 ? 1 : 0, " captures2,0 == 3\n";
    print "assert: ", captures()->[2]->[1] eq 'three' ? 1 : 0, " captures2,1 == three\n";
    
    print "assert: ", capture()->[0] == 1 ? 1 : 0, " capture0 == 1\n";
    print "assert: ", capture()->[1] eq 'one' ? 1 : 0, " capture1 == one\n";
    
    CODE
    
And run check:

    (a) <captures0,0 == 1> True
    (a) <captures0,1 == one> True
    (a) <captures1,0 == 2> True
    (a) <captures1,1 == two> True
    (a) <captures2,0 == 3> True
    (a) <captures2,1 == three> True
    (a) <capture0 == 1> True
    (a) <capture1 == one> True
    

That allows you to write tests in Perl5 Test::More `cmp_ok` way.

`matched()`, `captures()` and `capture()` are defined for all DSL compatible languages.

Matched data and captures are reset for every check step, meaning that the related functions return data for the _last_ check step.
But also see streams, that accumulated captures within search context.

# Capture(), captures(), matched() pitfalls

All those functions only store data matched or captured for the last check expression.

They don't accumulate data for the previous checks.

Consider this example:

Input:

```
1 hello
2 world
```
DSL:

```
regexp: \d \s hello
regexp: \d \s world

code<< CODE
!raku
for matches()<> -> $l {
   say $l
}
```

This will only print `2 world` as this
is a line where the last check expression matched

If you want to accumulate matched or captured data consider using , between: or begin: together with streams(), streams_array() functions. Streams always
accumulate matches data when used together with mentioned search scope modifiers

So as a rule use code: or generator: 
expression after every check expression
to handle captured, matched data:

```
regexp: \d
code: <<CODE
!raku
# handle matched data
CODE

regexp: \w
code: <<CODE
!raku
# handle matched data
CODE
```

# Soft checks

Soft checks is a special form of regexp expression check, so when a soft check matching fails the parser does not consider this as a failure, the fact of mismatch just printed out in report. If soft check matched it acts identically to regular ( none soft ) successful check 

Mostly soft checks are used together with generator/code expressions to implement
conditional or optional checks, here is an example:

Input:

```
My name is Alexey
```

DSL:

```
~regexp: "My name is" \s+ (\S+) \s+ (\S+)

code: <<RAKU
!raku
if matched() {
    my $firstname = capture()[0];
    my $lastname = capture()[1];
    say "Hi Mr $firstname $lastname";
} else {
   say "We need to know your firstname and lastname to greet you ...";
}
RAKU
```

So, use tilde before `regexp:` to make a _soft_ check. 

Another common scenario is to use soft checks together with replace feature.

# Comments, blank lines and here documents

Comments and blank lines are skipped by parser during checks execution, 
but may be added to a code for the sake of readability.

## Comments

Comment lines start with `#` symbol:

    # comments could take whole line, like here
    regexp: \d
    Hello World # or start after plain text check expression
    
## Blank lines

Blank lines are ignored.

DSL code:

    regexp: \d
    # following 2 blank lines
    # does not count
    # parser will script them

## Here documents

Here document format is used to add multiline code for generator and code expressions:

An example of validating that input contains date for yesterday:

    # check if input text has dates
    # formatted as  YYYY-MM-DD
    # and then check if the first date is yesterday
    
    regexp: date: (\d\d\d\d)-(\d\d)-(\d\d)
    
    generator: <<CODE
    !perl
    use DateTime;                       
    my $c  = captures()->[0];            
    my $dt = DateTime->new( year => $c->[0], month => $c->[1], day => $c->[2]  ); 
    my $yesterday = DateTime->now->subtract( days =>  1 );                        
    print 
    "assert: ",
    (DateTime->compare($dt, $yesterday) == 0) ? 1 : 0 , 
    " first day found is - $dt and this is a yesterday\n";
     CODE


Here document format string should start with
`<<`MARKER and has to have MARKER in the end.
Where MARKER is arbitrary unique string

Read generator and code doc sections to know more about code and generators.

# Search Context Modifiers

SCM change verification logic, _altering_ search context which is by default is the input data.

SCM always narrows down search context making verification criteria more strict. 

There are three types of search context modifiers:

* Sequences ( aka text blocks ) expressions
* Ranges expressions

# Sequence expressions

Sequences narrows down searched input data to the _consecutive_ sequence of lines, "insisting", that matched lines should go one by one:

Input:

    this string followed by
    that string followed by
    another one string
    with that string
    at the very end.

DSL:
    
    # this text block
    # consists of 5 strings
    # going consecutive

    begin:
        # plain strings
        this string followed by
        that string followed by
        another one
        # regexp patterns:
        regexp: with \s+  ( this || that ) 
        # and the last one in a block
        at the very end
    end:

Output:

    [task check]
    (s) <this string followed by> True
    (s) <that string followed by> True
    (s) <another one> True
    (s) <with \s+  ( this || that )> True
    (s) <at the very end> True
    

Letter `s` in parenthesis in output shows that search context changed to sequence.

A negative example:

Input:

    that string followed by
    this string followed by
    another one string
    with that string
    at the very end.
 
The same check will result in:
   
    (s) <this string followed by> True
    (s) <that string followed by> False
    (s) <another one> False
    (s) <with \s+  ( this || that )> False
    (s) <at the very end> False


## Sequence search expressions pitfalls

* `begin:`, `end:` markers denote start and end of a sequence. 

* Note, the markers should not be followed by any text at the same line.

* Be aware if you leave "dangling" `begin:` marker without closing `end:` parser will remain in sequence search context 
till the end of the file, which probably is not you want:

Example:

    begin:
        # sequence context starts here
        foo
        bar
        # and it will continue to the 
        # end of file
        # if we don't close it
        # through :end
    some-check # we still in `sequence search` context here

* You can't skip over blank lines in sequences expressions

Input:

    aaa
    bbb
    
    ccc
    
DSL:

    begin:
      aaa
      bbb
      ccc
    end:
    
Output:

    [task check]
    (s) <aaa> True
    (s) <bbb> True
    (s) <ccc> False
    
You need to match blank lines thought regexps:

    begin:
      aaa
      bbb
      regexp: ^^  $$
      ccc
    end:

## Sequence expressions limitations 

- between: end: blocks cannot be nested. You cannot have between: end: inside another between: end: block

- You cannot have between: end: blocks inside
   end:, between: end: blocks

# Range expressions

Range expressions also act like search context modifiers - they change search area to the one included
between lines matching right and left regular expression of between statement:

    between: {re1} {re2}

DSL parser uses Raku [^fff^](https://docs.raku.org/language/operators#infix_^fff^) operator to 
search within diapason.

It's technically equally to this Raku code:

    if /$re/ ^fff^ /$re2/

Thus, search context is narrowed down to the lines between line matching left regular expression and line matching right regular expression.

A matching (boundary) lines are not included in the range. 

Examples:

Parsing html output

Input:

    <table cols=10 rows=10>
        <tr>
            <td>one</td>
        </tr>
        <tr>
            <td>two</td>
        </tr>
        <tr>
            <td>the</td>
        </tr>
    </table>


DSL:

    # between expression:
    between: { '<table' .* '>' } { '</table>' }
      regexp: '<td>' (\S+) '</td>'
    end:
    
    # or even so
    between: { '<tr' .* '>' } { '</tr>' }
      regexp: '<td>' (\S+) '</td>'
    end:
    
Output:

    [task check]
    (r) <'<td>' (\S+) '</td>'> True
    (r) <'<td>' (\S+) '</td>'> True

## Range expressions pitfalls

* Resetting search context
        
As with sequences ranges expressions need to reset search context by using `:end` marker:

Input:

    foo
      hello
    bar

    hello
    hello

DSL:

    between: {foo} {bar}

      # all check expressions here
      # will be applied to the range
      # between /foo/ ^fff^ /bar/
  
      hello # should match 1 time
  
      generator: print "assert: ", ( scalar @{matched()} == 1 ? 1 : 0 ), " 1 hello within foo ... bar\n"; 
  
      # reset context, end of the range context:
  
    end:

    hello # should match three times

    generator: <<CODE
    !perl
    print "assert: ", ( scalar @{matched()} == 3 ? 1 : 0 ), " 3 hello within all document\n"; 
    CODE

Output:

    [task check]
    (r) <hello> True
    (a) <1 hello within foo ... bar> True
    <hello> True
    (a) <3 hello within all document> True

* Range expressions can't verify continuous sequences.

That means range expression only verifies that lines are _inside_ a range, not necessarily in consecutive order.

Example:

Input:

    
    foo
        1
        a
        2
        b
        3
        c
    bar


DSL:

    between: {foo} {bar}
       regexp: (1)
       code: print capture()->[0], "\n"
       regexp: (2)
       code: print capture()->[0], "\n"
       regexp: (3)
       code: print capture()->[0], "\n"
    end:

Output:

      (r) <(1)> True
      1
      (r) <(2)> True
      2
      <(3)> True
      3
      
If need to check consecutive sequences use sequence expressions.

* Nested ranges are not supported due to the nature of `^fff^` operator. 

The following example shows that:


Input:

    foo1
      foo2
        foo3
          foo4
        bar
      bar
    bar


DSL:

    between: {foo} {bar}
    regexp: (foo \d+)
    code: <<CODE
    !perl
    use Data::Dumper; print Dumper(captures());
    CODE

Output:

    stdout match (r) <(foo \d+)> True
    $VAR1 = [
              [
                'foo2'
              ],
              [
                'foo3'
              ],
              [
                'foo4'
              ]
            ];
    
* Don't enclose in quotes between:
  start and stop regular expressions
  
  
## Range expressions limitations 

- between: end: blocks cannot be nested. You cannot have between: end: inside another between: end: block

- You cannot have between: end: blocks inside
   end:, begin: end: blocks
  
# Generators

* Generators is the way to _generate check expressions on the _fly_

* Generator expressions like code expressions are just pieces of executable code

* Everything that generator code print to _stdout_ is _treated_ as new DSL code and parsed by DSL parser

* So new DSL terms are passed back to DSL parser and executed immediately

Generator expressions should start with `generator:` marker, followed by `<<HERE` doc marker that defines the start of generator block.

The very first line of generator block should contain language identification in form of `!language` to define programming language
to be used to execute generator block, for instance:

```
!python
```

The end of generator block should be closed
by HERE doc marker. 

More generator examples:

Input text:

    HELLO

DSL:

    generator: <<CODE
    !perl
    print join "\n", ('H', 'E', 'L', 'O');
    CODE

Output:

    [task check]
    <H> True
    <E> True
    <L> True
    <O> True
    
Here are examples for other languages:

Input text:
    
    Say
    Hello
    First
    
This generator creates 3 new check expressions:

Bash:

    generator: <<CODE
    !bash
      echo Say
      echo Hello
      echo 'regexp: Hello || Again'
    CODE

Ruby:

    generator: <<CODE
    !ruby
      puts 'Say'
      puts 'Hello'
      puts 'regexp: Hello || Again'
    CODE

Output:

    [task check] 
    <Say> True
    <Hello> True
    <Hello || Again> True

Here is more complicated example of using Perl language.

Input:

    foo value
    bar value

DSL:

    # this generator creates
    # comments
    # and plain string 
    # check expressions

    generator: <<CODE
    !perl
     my %d = ( 'foo' => 'foo value', 'bar' => 'bar value' );
    
     print join "\n", map { ( "# $_ ", $d{$_} ) } keys %d;
      
    CODE
    
Output:

    [task check]
    <bar value> True
    <foo value> True
    
Generators could produce not only check expressions but code expressions and another generators.

Generators are often used to create an asserts from captures. 

This is short example for Ruby language:

    number: (\d+)
    
    generator: <<CODE
    !ruby
        puts "assert: #{capture()[0] == 10}, you've got 10!"  
    CODE

Generator expressions could use all the functions provided by Sparrow Task SDK - https://github.com/melezhik/Sparrow6/blob/master/documentation/development.md

## Generators pitfalls

- Always set language identification on the very first line of generator block, or else default language (Perl) will be applied which is not probably what you want 

- For generator expressions written on Python
if Sparrow SDK functions are used (
matched(), captures(), capture(), streams-array(), config(), os(), get_state(), update_state(), etc you have to import those functions from sparrow6lib to make them available inside generator expression block:

```
generator: <<CODE
!python
from sparrow6lib import *
c = capture()
conf = config()
CODE
```

# Asserts

Asserts expressions are statements that are true or false.

False assert statement always results in
task check failure.

Assert expression should be written in form:

`assert: {value} {short description}`

value should be one of the following

- 1
- true
- True
- 0
- false
- False

1, true, True are used for true assert statements,
0, false, False for false assert statements.

The second short description parameter of assert expression used for informative purposes, so it's just printed in report

Assert expression examples:

DSL: 
    assert: 1 this is true
    assert: 0 this is false
    assert: True this is also true, Raku style 
    assert: False this is false, Raku style 
    assert: true this is true, python/ruby style 
    assert: false this is false, python/ruby style 

Output:

    [task check]
    (a) <this is true> True
    (a) <this is false> False
    (a) <this is also true, Raku style> True
    (a) <this is false, Raku style> False
    (a) <this is true, python/ruby style> True
    (a) <this is false, python/ruby style> False
    
Asserts are almost always created dynamically with generators. See the next section.

## Asserts expressions pitfalls

- Strictly follow expression value format, should be on of the following - 1,true,True,0,false,False If the value is incorrect or empty task check parser will treat it as plan text check expression, following are some incorrect assert expressions examples:

```
# wrong format of assert value
assert: OK this never works

# empty assert value:
assert: ok
```

- When generating assert expressions via generators follow programming languages documentation on how to convert language native types into assert expression value format
