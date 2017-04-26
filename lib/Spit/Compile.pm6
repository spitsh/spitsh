# A home for the main compilation pipeline entrypoint
unit module Spit::Compile;

use Spit::Util :light-load;

sub compile  ($input is copy,
              :$*SETTING is copy,
              :$debug,
              :$target = 'compile',
              :%opts,
              :$outer,
              :$name is required,
              :$no-inline,
              :$one-block,
              *%,
             ) is export {

    # if we are compiling the SETTING itself $*SETTING will be set to False so
    # it won't trigger this.
    without $*SETTING {
        $_ = (once light-load 'Spit::PRECOMP', export-target => '$SETTING')
    }

    my $*CU-name = $name;
    if $input ~~ Str {
        my \SPIT_ACTIONS = (once light-load 'Spit::Parser::Actions', target => 'Spit::Actions');
        my \SPIT_GRAMMAR = (once light-load 'Spit::Parser::Grammar', target => 'Spit::Grammar');
        my $parser  = SPIT_GRAMMAR.new;
        my $actions = SPIT_ACTIONS.new(:$outer, :$debug);
        my $*ACTIONS = $actions;
        note "$name parsing.. " if $debug;
        my \before = now;
        my $match = $parser.parse($input,:$actions);
        die "Parser completely failed to match input ($name)" unless $match;
        note "$name parsing ✔ {now - before}" if $debug;
        $input = $match.made;
        return $match if $target eq 'parse';
        return $input if $target eq 'stage1';
    }

    if $input.isa('SAST::CompUnit') {

        if not $input.stage2-done {
            note "$name contextualzing.." if $debug;
            my \before = now;
            $input .= do-stage2();
            note "$name contextualzing ✔ {now - before}" if $debug;
            return $input if $target eq 'stage2';
        }

        my \SPIT_COMPILER = (once light-load 'Spit::Sh::Compiler');
        my $compiler = SPIT_COMPILER.new(:%opts);

        if not $input.stage3-done {
            note "$name composing.." if $debug;
            my \SPIT_COMPOSER = (once light-load 'Spit::Sh::Composer');
            my \before = now;
            SPIT_COMPOSER.new(
                :%opts,
                scaffolding => $compiler.scaffolding,
                :$no-inline,
            ).walk($input);
            note "$name composing ✔ {now - before}" if $debug;
            return $input if $target eq 'stage3'
        }

        if $input.stage3-done {
            note "$name compiling.." if $debug;
            my \before = now;
            $input = $compiler.compile($input, :$one-block);
            note "$name compiling ✔ {now - before}" if $debug;
        }

    } else {
        die "Can't compile a {$input.^name}";
    }

    $input;
}
