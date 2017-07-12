use Test; plan 6;

{
    my @a = <zero one two three>;
    is @a[1,3], <one three>, '@a[1,3]';

    is @a[ ($_ + 1 for ^3) ], <one two three>,
      '@a[($_ + 1 for ^3)]';

    is @a[ (^4).grep(/0|3/) ], <zero three>,
      '@a[ (^4).grep(/0|3/) ]';


    {
        class Foo is List[Int] {}

        is @a[Foo<1 2 3>.list], <one two three>,
          'post-declared method that returns a list as an index';

        augment Foo {
            method list^ is no-inline { $self }
        }
    }

    my @b = 1,2;
    is @a[@b], <one two>, '@a[@b]';
    is @a[ (my @c = ^3; @c) ], <zero one two>, '@a[(my @c = ^3; @c)]';

}
