use strict;
use warnings;

use Test::More;
use Test::Exception;
use Parse::Method::Signatures;

my @sigs = (                                                                # invocant is omited in the Signature[] translations
    ['()',                      'empty signature'],                         # Signature[]
    ['($x)',                    'single required positional'],              # Signature[,Any]
    ['($x:)',                   'invocant only'],                           # Signature[]
    ['($x, $y)',                'two required positionals'],                # Signature[Any, Any]
    ['($x where { $_->isa("Moose") })',                                     # Signature[subtype Any, where { $_->isa('Moose') }]
                                'with constraint'],
    ['($x where { $_->isa("Moose") } where { $_->does("Gimble") })',        # Signature[subtype Any, where { $_->isa('Moose') && $_->does('Gimble') }]
                                'multiple constraints'],
    ['(Str $name)',             'typed positional'],                        # Signature[Str]
    ['(Int $x, Str $y)',        'multiple typed positionals'],              # Signature[Int, Str]
    ['(Animal|Human $affe)',    'type constraint alternative'],             # Signature[Animal|Human]
    ['(Some::Class $x)',        'type constraint with colon'],              # Signature[Some::Class]
    ['(Tuple[Int,Str] $x)',     'parameterized types'],                     # Signature[Tuple[Int,Str]]
    ['(Str|Tuple[Int,Str] $x)', 'parameterized with alternative'],          # Signature[Str|Tuple[Int,Str]]
    ['($: $x, $y, $z)',         'dummy invocant'],                          # Signature[Any, Any, Any]
    ['($, $, $x)',              'dummy positionals'],                       # Signature[Any, Any, Any]
    ['($x, @)',                 'dummy list'],                              # Signature[Any, List]
    ['(:$x)',                   'optional named'],                          # Signature[Named[Optional[x=>Any]]]
    ['(:$x!)',                  'required named'],                          # Signature[Named[x=>Any]]
    ['(Str :$x)',               'named with type constraint'],              # Signature[Named[Optional[x=>Str]]]
    ['($x, $y, :$z)',           'positional and named'],                    # Signature[Any, Any, Named[Optional[z=>Any]]]
    ['($x, $y?, :$z)',          'optional positional and named'],           # invalid
    ['(:$a, :$b, :$c)',         'multiple named'],                          # Signature[Named[Optional[x=>Any], Optional[y=>Any], Optional[y=>Any]]]
    ['($a, $b, :$c!, :$d!)',    'positional and multiple required named'],  # Signature[Any, Any, Named[c=>Any, d=>Any]]
    ['($a?, $b?, :$c, :$d)',    'optional positional and named'],           # Signature[Optional[Any], Optional[Any], Named[Optional[c=>Any], Optional[d=>Any]]]  -- quite possibly invalid
    ['(:$x! where { 1 })',      'required named with constraint'],          # Signature[Named[x=>subtype Any, where { 1 }]]
    ['($self: $moo)',           'invocant and positional'],                 # Signature[Any]
    ['(:apan($affe))',          'long named'],                              # Signature[Named[Optional[apan=>Any]]]
    ['(:apan($affe)!)',         'required long named'],                     # Signature[Named[apan=>Any]]
    ['($self: :$x)',            'named param with invocant'],               # Signature[Named[Optional[x=>Any]]]
    ['($: :$x)',                'named param with dummy invocant'],         # Signature[Named[Optional[x=>Any]]]
    ['($x = 42)',               'positional with default'],                 # Signature[Optional[Any]]
    ['(:$x = 42)',              'named with default'],                      # Signature[Named[Optional[x=>Any]]]
    ['($x = "foo")',            'simple string default'],                   # Signature[Optional[Any]]
    ['($x = "foo, bar")',       'string default with comma'],               # Signature[Optional[Any]]
    ["(\$x = 'foo, bar')",      'single quoted default with comma'],        # Signature[Optional[Any]]
    ['($x = q"foo")',           'default with q"" quoting'],                # Signature[Optional[Any]]
    ['($x = q{foo})',           'default with q{} quoting'],                # Signature[Optional[Any]]
    ['($x = q(foo))',           'default with q() quoting'],                # Signature[Optional[Any]]
    ['($x = q,foo,)',           'default with q,, quoting'],                # Signature[Optional[Any]]
    ['($x, $y = $x)',           'default based on other paramter'],         # Signature[Any, Any]
    ['(Str :$who, Int :$age where { $_ > 0 })',                             # Signature[Named[Optional[who=>Str], Optional[age=>subtype Int, where { $_ > 0 }]]]
                                'complex with constraint'],
    ['(Str $name, Bool :$excited = 0)',                                     # Signature[Str, Named[Optional[ecited=>Bool]]]
                                'complex with default'],
    [q#(SomeClass $thing where { $_->can('stuff') }: Str $bar = "apan", Int :$baz = 42 where { $_ % 2 == 0 } where { $_ > 10 })#,
                                                                            # Signature[Str, Named[Optional[baz=>subtype Int, where { $_ % 2 == 0 && $_ > 10 }]]]
                                'complex invocant, defaults and constraints'],
    ['(@x)',                    'positional array'],                        # Signature[List]
    ['($x, @y)',                'positinal scalar and array'],              # Signature[Any, List]
    ['(%x)',                    'positinal hash'],                          # Signature[EvenList]
    ['($x, %y)',                'positinal scalar and hash'],               # Signature[Any, EvenList]
    ['([$x, $y])',              'simple array ref unpacking'],              # Signature[Tuple[Any, Any]]
    ['([@x])',                  'array ref unpacking into array'],          # Signature[Tuple[List]] or maybe just Signature[ArrayRef]
    ['([$x, $y, @rest])',       'array ref unpacking into scalars and arrays'],
                                                                            # Signature[Tuple[Any, Any, List]]
    ['($x, [$y, $z, @rest])',   'array ref unpacking combined with normal positionals'],
                                                                            # Signature[Any, Tuple[Any, Any, List]]
    ['([$y, $z, @rest], $x)',   'array ref unpacking combined with normal positionals'],
                                                                            # Signature[Tuple[Any, Any, List], Any]
    ['([$y, $z, @rest], :$x)',  'array ref unpacking combined with named'],
                                                                            # Signature[Tuple[Any, Any, List], Named[Optional[x=>Any]]]
    ['(:foo([$x, $y, @rest]))', 'named array ref unpacking'],               # Signature[Named[Optional[foo=>Tuple[Any, Any, List]]]]
    ['({%x})',                  'hash ref unpacking into hash'],            # Signature[Dict[EvenList]]
    ['({:$x, :$y, %rest})',     'hash ref unpacking into scalars and hash'],
                                                                            # Signature[Dict[Named[Optional[x=>Any], Optional=>[y=>Any], EvenList]]]
    ['($x, {:$y, :$z, %rest})', 'hash ref unpacking combined with normal positionals'],
                                                                            # Signature[Any, Dict[Named[Optional[x=>Any], Optional=>[y=>Any], EvenList]]]
    ['({:$y, :$z, %rest}, $x)', 'hash ref unpacking combined with normal positionals'],
                                                                            # Signature[Dict[Named[Optional[x=>Any], Optional=>[y=>Any], EvenList]], Any]
    ['({:$x, :$y, %r}, :$z)',   'hash ref unpacking combined with named'],
                                                                            # Signature[Dict[Named[Optional[x=>Any], Optional=>[y=>Any], EvenList]], Named[Optional[z=>Any]]]
    ['(:foo({:$x, :$y, %r}))',  'named hash ref unpacking'],
                                                                            # Signature[Named[Optional[foo=>Dict[Named[Optional[x=>Any], Optional[y=>Any], EvenList]]]]]
    ['(:foo($), :bar(@))',      'named placeholders'],                      # invalid
    ['(Foo[Bar|Baz[Moo]]|Kooh $foo)',                                       # Signature[Foo[Bar|Baz[Moo]]|Kooh]
                                'complex parameterized type'],
    ['($foo is coerce)',        'positional with traits (is)'   , 'traits not implemented yet'],
    ['($foo does coerce)',      'positional with traits (does)' , 'traits not implemented yet'],
    ['(:$foo is coerce)',       'named  with traits (is)'       , 'traits not implemented yet'],
    ['(:$foo does coerce)',     'named with traits (does)'      , 'traits not implemented yet'],
    ['($foo is copy is ro does coerce)',
                                'multiple traits',                'traits not implemented yet'],
);

my @alternative = (
    [q{($param1, # Foo bar
        $param2?)},             '($param1, $param2?)',     'comments in multiline'],
    ['(:$x = "foo")',           '(:$x = "foo")',           'default value stringifies okay'],
    ['($self: $moo)',           '($self: $moo)',           'invocant and positional'],
    ['(Animal | Human $affe)',  '(Animal|Human $affe)',    'type constraint alternative with whitespace'],
);

my @invalid = (
    ['($x?:)',                  'optional invocant'],
    ['(@x:)',                   'non-scalar invocant'],
    ['(%x:)',                   'non-scalar invocant'],
    ['($x?, $y)',               'required positional after optional one'],
    ['(Int| $x)',               'invalid type alternation'],
    ['(|Int $x)',               'invalid type alternation'],
    ['(@x, $y)',                'scalar after array'],
    ['(@x, @y)',                'multiple arrays'],
    ['(%x, %y)',                'multiple hashes'],
    ['(@, $x)',                 'scalar after array placeholder'],
    ['(:@x)',                   'named array'],
    ['(:%x)',                   'named hash'],
    ['(:@)',                    'named array placeholder'],
    ['(:%)',                    'named hash placeholder'],
    ['(:[@x])',                 'named array ref unpacking without label'],
    ['([:$x, :$y])',            'unpacking array ref to something not positional'],
    ['(:{%x})',                 'named hash ref unpacking without label'],
    ['({$x, $y})',              'unpacking hash ref to something not named'],
    ['($foo where { 1, $bar)',  'unbalanced { in conditional'],
    ['($foo = `pwd`)',          'invalid quote op'],
    ['($foo = "pwd\')',         'unbalanced quotes'],
    ['(:$x:)',                  'named invocant is invalid'],
    ['($x! = "foo":)',          'default value for invocant is invalid'],
    ['($foo is bar moo is bo)', 'invalid traits'],
);

plan tests => scalar @sigs * 3 + scalar @alternative + scalar @invalid;

test_sigs(sub {
    my ($input, $msg, $todo) = @_;
    my $sig;
    lives_ok {
        $sig = Parse::Method::Signatures->signature($input);
    } $msg;
    isa_ok($sig, 'Parse::Method::Signatures::Sig', $msg);
    TODO: {
        todo_skip $todo, 1 if $todo && !$sig;
        is($sig->to_string, $input, $msg);
    }
}, @sigs);

for my $row (@alternative) {
    my ($in, $out, $msg) = @{ $row };
    lives_and {
        is(Parse::Method::Signatures->signature($in)->to_string, $out, $msg)
    } $msg;
}

test_sigs(sub {
    my ($sig, $msg) = @_;
    dies_ok { Parse::Method::Signatures->signature($sig) } $msg;
}, @invalid);

sub test_sigs {
    my ($test, @sigs) = @_;

    for my $row (@sigs) {
        my ($sig, $msg, $todo) = @{ $row };
        TODO: {
            local $TODO = $todo if $todo;
            $test->($sig, $msg, $todo);
        }
    }
}
