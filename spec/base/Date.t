use Test;

plan 24;

given DateTime<2017-05-03T04:03:06.042> {
    ok .valid, 'is valid';
    is .year,    2017, '.year';
    is .month,   5,    '.month';
    is .day,     3,    '.day';
    is .hour,    4,    '.hour';
    is .minute,  3,    '.minute';
    is .second,  6,    '.second';
    is .milli,   42,   '.milli';
    is .posix, 1493784186, '.posix';

    is .Date, '2017-05-03', '.Date';
}

nok DateTime<2017-05-03T04:03:06.042Z>.valid, 'timezone is invalid';

given Date<2017-05-03> {
    is .year,    2017, 'date only .year';
    is .month,   5,    'date only .month';
    is .day,     3,    'date only .day';

    is .DateTime.milli, 0, '.Datetime';
}

{
    given now() {
        ok .year.starts-with('20'),  'sanity .year';
        ok .month ~~ /^(1[0-2]|[1-9])$/, 'sanity .month';
        ok .day ~~ /^([1-9]|[12]\d|3[01])$/, 'sanity .day';
        ok .dow ~~ /^[0-6]$/, 'sanity .dow';
        ok .hour ~~ /^(1?[0-9]|2[0-3])$/, 'sanity .hour';
        ok .minute ~~ /^([1-5]?[0-9])$/, 'sanity .minute';
        ok .second ~~ /^([1-5]?[0-9])$/, 'sanity .second';
        ok .milli  ~~ /^\d{1,3}$/, 'sanity .milli';
        ok .posix ~~ /^\d+$/, 'sanity .posix';
    }
}
