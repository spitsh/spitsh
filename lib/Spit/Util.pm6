unit module Spit::Util;
use Spit::Constants;

sub descend-WHO($WHO is copy,Str:D $path) {
    my @parts = $path.split('::');
    while @parts.shift -> $part {
        if @parts == 0 {
            return $WHO{$part};
        } else {
            return Nil unless $WHO{$part}:exists;
            $WHO = $WHO{$part}.WHO;
        }
    }
    Nil;
}

sub remove(@array,\test --> Bool) is export(:remove) {
    my int $len = +@array;
    loop (my int $i = 0; $i < $len; $i++) {
        if (@array[$i]) ~~ test {
            @array.splice($i,1);
            return True;
        }
    }
    False;
}

sub get-globalish($short-name) is export(:get-globalish) {
    $*REPO.need(CompUnit::DependencySpecification.new(:$short-name)).handle.globalish-package;
}

sub light-load($short-name,:$target = $short-name,:$export-target) is export(:light-load) {
    my $handle := $*REPO.need(CompUnit::DependencySpecification.new(:$short-name)).handle;
    with $export-target {
        $handle.export-package<ALL>.WHO.{$_};
    } else {
        $handle.globalish-package.&descend-WHO($target);
    }
}

sub sha1(Str:D $str --> Str:D) is export(:sha1) {
    use nqp;
    return nqp::sha1($str);
}

sub force-recompile($module) is export(:force-recompile) {
    if $*REPO.repo-chain».loaded.flat.first($module) -> $cu {
        my $repo = $cu.repo;
        if $repo ~~ CompUnit::Repository::FileSystem
           and $cu.precompiled
        {
               $repo.precomp-repository.store.path(
                   CompUnit::PrecompilationId.new($*PERL.compiler.id),
                   CompUnit::PrecompilationId.new($cu.repo-id),
               ).unlink
        } else {
            note $repo.^name;
        }
    }
}
sub spit-version is export(:spit-version) {
    once do {
        use JSON::Tiny;
        (try $*REPO.resolve(CompUnit::DependencySpecification.new(:short-name<Spit::Compile>)).distribution.meta<ver>)
        or
        Version.new('META6.json'.IO.slurp.&from-json<version>);
    }
}


sub SETTING-lookup(SymbolType \symbol-type, $name) is export(:SETTING-lookup) {
    require Spit::PRECOMP <$SETTING>;
    $SETTING.lookup(symbol-type, $name);
}

# removes ansicolors from text
sub colorstrip($_) is export(:colorstrip) { S:g/\e\[ <[0..9;]>+ m// }
