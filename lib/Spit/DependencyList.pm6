need Spit::SAST;
need Spit::Exceptions;
use Spit::Util :remove;

# See below for explanation
class Spit::DependencyList {

    has SetHash $!added .= new;
    has SAST:D @.deps;
    has %.by-orig;
    has %!scaf-by-orig;
    has %!scaf-by-name;
    has $!iterator-array;

    method add-dependency($d) {
        if not $!added{$d} {
            @!deps.push($d);
            $!added{$d} = True;
            %!by-orig{$d.identity} = $d;
        }
    }

    method get-dependency(Any:D $orig) {
        %!by-orig{$orig}
    }

    method add-scaffolding($scaf,:$name) {
        $scaf.make-new(
            SX::Bug,
            desc => "tried to add scaffolding ($scaf.gist) which isn't stage3 to dependency list"
        ).throw  unless $scaf.stage3-done;

        %!scaf-by-orig{$scaf.identity} = $scaf;
        %!scaf-by-name{$name} = $scaf if $name;
    }

    method get-scaffolding(Str:D $name) {
        %!scaf-by-name{$name};
    }

    multi method require-scaffolding(Any:D $sast is copy) {
        $sast = %!scaf-by-orig{$sast} without $sast.cloned;

        if $!added{$sast} {
            with $!iterator-array {
                .unshift($sast) if .&remove($sast);
            }
            @!deps.&remove($sast);
            @!deps.unshift($sast);
        } else {
            @!deps.unshift($sast);
            $!added{$sast} = True;
            .unshift($sast) with $!iterator-array;
        }

        self.require-scaffolding($_) for $sast.child-deps;

        $sast;
    }

    multi method require-scaffolding(Str:D $name) {
        self.require-scaffolding(%!scaf-by-name{$name});
    }

    method reverse-iterate(&block) {
        $!iterator-array = [@!deps];
        my @res;
        while $!iterator-array.pop -> $item {
            @res.unshift: &block($item);
        }
        $!iterator-array = Nil;
        @res;
    }

    method gist {
        @!deps».gist.join("\n");
    }
}

# I think I have figured out how this works:
# The DependencyList before the compilation stage is ordered by the following:
# (most dominant to least)
# - The vertically higher the first dependent statement is in the AST the
#   LOWER its position in @!deps will be.
# - If equal above, The further RIGHT its dependent is horizontally within the
#   statement the LOWER its position
# - If equal above The DEEPER it is within the dependency chain the LOWER its
#   position
#
# The sumamry of the above is the most deeply depended upon thing is at @!deps[0]
#
# Later, when compiling we have the scaffolding problem.
#
# 1. compile MAIN, unshifting any scaffolding onto the front of the list
# 2. reverse iterate @!deps, compiling each item, unshifting any scaffolding
#    onto the front of the list. If any scaffolding exists in @!deps already,
#    remove it and unshift it onto the front of @!deps
