use Test; plan 3;

{
    given Docker.create("alpine").cleanup {
        ok  .exec(eval{ ${true} }), 'eval that exists true';
        nok .exec(eval{ ${false} }), 'eval that exits false';
        nok .exec(eval{ die "dieing"; ${true}; }), 'eval that dies returns false';
    }
}
