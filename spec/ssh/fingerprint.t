use Test; plan 2;

if $:os ~~ CentOS {
    skip 'centos has an old ass version of openssh', 2;
}

else  {
    given 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFofjAwqt5UV/SIDlZmu6blGAStuRXJ4CawlExwnps55 root@b5978f0527b8'-->SSH-public-key {
        is .fingerprint,'BHSSQSQhSqsX1U+RoZ+vVBaeiLUHHQ6fISqBhGzvYQo',
        '.fingerprint';
        is .fingerprint(:algo<md5>), '0b:dc:d8:15:5c:8e:ec:f9:31:26:83:25:1c:c7:a8:4d',
        '.fingerprint(:algo<md5>)';
    }
}
