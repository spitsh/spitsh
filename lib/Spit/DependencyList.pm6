need Spit::SAST;
need Spit::Exceptions;
use Spit::Util :remove;

# See below for explanation
class Spit::DependencyList {

    has $!set = SetHash.new;
    has @.list;
    has %.by-orig;
    has %!scaf-by-orig;
    has %!scaf-by-name;
    has $!iterator-array;

    method add-dependency($d) {
        if not $!set{$d} {
            @!list.push($d);
            $!set{$d} = True;
            die "Tried to depend on a synthetic node" unless $d.cloned;
            %!by-orig{$d.cloned} = $d;
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

        die "Scaffolding can't be a synthetic node" unless $scaf.cloned;
        %!scaf-by-orig{$scaf.cloned} = $scaf;
        %!scaf-by-name{$name} = $scaf if $name;
    }

    method get-scaffolding(Str:D $name) {
        %!scaf-by-name{$name};
    }

    multi method require-scaffolding(Any:D $sast is copy) {
        $sast = %!scaf-by-orig{$sast} without $sast.cloned;

        if $!set{$sast} {
            with $!iterator-array {
                .unshift($sast) if .&remove($sast);
            }
            @!list.&remove($sast);
            @!list.unshift($sast);
        } else {
            @!list.unshift($sast);
            $!set{$sast} = True;
            .unshift($sast) with $!iterator-array;
        }

        self.require-scaffolding($_) for $sast.all-deps;

        $sast;
    }

    multi method require-scaffolding(Str:D $name) {
        self.require-scaffolding(%!scaf-by-name{$name});
    }

    method reverse-iterate(&block) {
        $!iterator-array = [@!list];
        my @res;
        while $!iterator-array.pop -> $item {
            @res.unshift: &block($item);
        }
        $!iterator-array = Nil;
        @res;
    }

    method gist {
        @!list».gist.join("\n");
    }
}

# I think I have figured out how this works:
# The DependencyList before the compilation stage is ordered by the following:
# (most dominant to least)
# - The vertically higher the first dependent statement is in the AST the
#   LOWER its position in @!list will be.
# - If equal above, The further RIGHT its dependent is horizontally within the
#   statement the LOWER its position
# - If equal above The DEEPER it is within the dependency chain the LOWER its
#   position
#
# The sumamry of the above is the most deeply depended upon thing is at @!list[0]
#
# Later, when compiling we have the scaffolding problem.
#
# 1. compile MAIN, unshifting any scaffolding onto the front of the list
# 2. reverse iterate @!list, compiling each item, unshifting any scaffolding
#    onto the front of the list. If any scaffolding exists in @!list already,
#    remove it and unshift it onto the front of @!list
