use Test;

plan 5;

{
    my $img1 = Docker.create('alpine').commit( labels => (one => "two", three => "four") ).cleanup;
    my $img2 = Docker.create('alpine').commit( labels => (one => "two", five => "four") ).cleanup;

    my @one-two = DockerImg.images(labels => (one => "two"));
    is +@one-two, 2, 'two images with shared label';

    my @three-four = DockerImg.images(labels => (three => "four"));
    is +@three-four, 1, 'one image with label';
    is @three-four[0], $img1, 'it was the one we labeled';


    my @one-two-three-four = DockerImg.images:
       labels => (one => "two", three => "four");

    is +@one-two-three-four, 1, 'multiple lables are conjunctive';
    is @one-two-three-four[0], $img1, ‘multiple labels result is the one expected’;

}
