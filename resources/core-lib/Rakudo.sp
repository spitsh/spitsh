#| Very experimental class for building Rakudo and Rakudo based images.
class Rakudo {

    constant File $:install-to;
    constant $:checkout = '2017.07';
    constant File $:clone-to = './rakudo';
    constant GitHub $:zef-repo = 'ugexe/zef';
    constant GitHub $:repo = 'rakudo/rakudo';
    constant Bool $:debug-moar;

    static method install-deps on {
        Alpine {  Pkg<linux-headers musl-dev>.install }
    }

    static method build(
         :$checkout = $:checkout,
         :$install-to = $:install-to,
         :$clone-to = $:clone-to,
    Bool :$debug-moar = $:debug-moar,
    ) {
        Rakudo.install-deps;

        $:repo.clone(to => $clone-to).cd;

        ok ${ $:git checkout $checkout !>warn },
        "rakudo git checkout $checkout";

        ok ${
            $:perl 'Configure.pl' >debug/warn('Configure.pl')
            ('--moar-option=--debug=3' if $debug-moar)
            --gen-moar --gen-nqp ("--prefix=$_" if $install-to )
        },
        'Configure.pl ran successfully';

        ok ${ $:gcc-make install >debug/warn('rakudo-build') },
        'rakudo built successfully';
    }

    constant File $img-clone-to = "$:HOME/rakudo-src";
    constant File $img-install-to = "$:HOME/rakudo";
    constant File $zef-clone-to = "$:HOME/zef";

    static method build-image(
         :$checkout = $:checkout,
    Bool :$debug-moar = $:debug-moar
    ) -->DockerImg is export
    {
        my @labels = (rakudo => 'build', :$checkout, :$debug-moar);

        if DockerImg.images(:@labels) {
            debug "rakudo-build($checkout) already exists";
            $_[0];
        }
        else {
            my $rakudo-build =  Docker.create('alpine').cleanup;
            ok $rakudo-build.exec(
                eval(os => Alpine, :$checkout, :$debug-moar){
                    Rakudo.build(
                        clone-to => $img-clone-to,
                        install-to => $img-install-to,
                    )
                }
            ),
            'build script executed sucessfully';

            $rakudo-build.commit: :@labels;
        }
    }

    static method bare-image(
         :$checkout = $:checkout,
    Bool :$debug-moar = $:debug-moar
    ) -->DockerImg is export
    {
        my @labels = (rakudo => 'bare', :$checkout, :$debug-moar);
        if DockerImg.images(:@labels) {
            debug "rakudo-bare($checkout) already exists";
            $_[0];
        }
        else {
            my $build = Rakudo.build-image(:$checkout);
            my $bare  = Docker.create('alpine').cleanup;
            my $built = $build.copy-from: $img-install-to, $img-install-to.parent;
            $bare.copy: $built.add($img-install-to.name), $img-install-to.parent;

            $bare.commit(
                env => "PATH { $img-install-to.add('bin') }:{$img-install-to.add('share/perl6/site/bin')}:$?PATH:",
                entrypoint => 'perl6',
                :@labels,
            );
        }
    }

    static method zef-image(
         :$checkout = $:checkout,
    Bool :$debug-moar = $:debug-moar,
    ) -->DockerImg
    {
        my @labels = (rakudo => 'zef', :$checkout, :$debug-moar);
        if DockerImg.images(:@labels) {
            debug "rakudo-zef($checkout) already exists";
            $_[0];
        }
        else {
            my $bare = Rakudo.bare-image(:$checkout);

            my $rakudo-zef = Docker.create($bare).cleanup;

            my $zef = $:zef-repo.clone;

            $rakudo-zef.copy: $zef, $zef-clone-to;

            my $exec = eval(os => Alpine, :log){
                $zef-clone-to.cleanup.cd;
                ok $:curl && $:git, 'git and curl installed as a backend for zef';
                ${perl6 -Ilib 'bin/zef' install '.' >debug/warn('zef')}
            };

            ok $rakudo-zef.exec($exec), 'zef install';

            $rakudo-zef.commit( entrypoint => 'perl6',  :@labels );
        }
    }
}
