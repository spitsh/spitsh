constant $:build-os = Alpine;
constant $:tag = $?spit-version;
constant $:image-name = 'spit-helper';

constant $build = eval(os => $:build-os, :log){
    Pkg<jq>.install;
    ok ${$:curl --version   >info}, 'curl version';
    ok ${$:docker --version >info}, 'docker version';
    ok ${$:git --version    >info}, 'git version';
    ok ${jq --version       >info}, 'jq version';
    ok ${$:ssh -V          !>info}, 'ssh version';
    ok ${$:socat -V >X} &&
          ${$:socat -V | head -n2 >info:socat}, 'socat version';
};

info "starting build of $:image-name:$?spit-version";

given Docker.create('alpine', :name<spit-helper-builder>, :mount-socket).cleanup {
    # copy docker binary to the container
    .copy($:docker.path, $:docker.path);

    info "exec()ing helper build script in container";

    # run the build script
    ok .exec($build), 'build script ran successfully';

    info 'Removing old spit-helper images';
    DockerImg.images(has-labels => 'spit-helper').remove;

    if .commit(name => $:image-name, labels => ('spit-helper' => $:tag)) -> $image {
        $image.add-tag($:tag);
    } else {
        die "Failed to build $:image-name";
    }
}
