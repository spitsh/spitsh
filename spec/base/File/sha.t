use Test; plan 3;
{
    given File.tmp {
        constant $foo-sha256 = 'b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c';

        .write: "foo\n";
        is .sha256, $foo-sha256, '.sha256 correct';

        nok eval{ .sha256-ok: $foo-sha256.subst('b','c') }.${sh !>X},
        '.sha256-ok wrong dies';

        .sha256-ok($foo-sha256);
        pass '.sha256-ok right lives';
    }
}
