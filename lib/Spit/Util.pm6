unit module Spit::Util;

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
