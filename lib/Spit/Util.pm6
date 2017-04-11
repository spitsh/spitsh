unit module Spit::Util;

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

sub light-load($short-name,:$target = $short-name) is export(:light-load) {
    $*REPO.need(CompUnit::DependencySpecification.new(:$short-name)).handle.globalish-package\
          .&descend-WHO($target);
}
