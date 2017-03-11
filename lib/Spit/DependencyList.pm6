need Spit::SAST;
need Spit::Exceptions;
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
            .push($d) with $!iterator-array;
        }
    }

    method get-dependency(Any:D $orig) {
        %!by-orig{$orig}
    }

    method add-scaffolding($scaf) {
        $scaf.make-new(SX::Bug, desc => "scaffolding ($scaf.gist) which isn't stage3 tried to be added").throw
            unless $scaf.stage3-done;
        die "Scaffolding can't be a synthetic node" unless $scaf.cloned;
        %!scaf-by-orig{$scaf.cloned} = $scaf;
        %!scaf-by-name{$scaf.name} = $scaf if $scaf ~~ SAST::Declarable;
    }

    method get-scaffolding(Str:D $name) {
        %!scaf-by-name{$name};
    }

    multi method require-scaffolding(Any:D $sast is copy) {
        $sast = %!scaf-by-orig{$sast} without $sast.cloned;
        self.require-scaffolding($_) for $sast.all-deps;
        self.add-dependency($sast);
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
