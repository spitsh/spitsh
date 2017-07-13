augment Pair {
    method value -->Value { $self.${cut -f2- | tr -d '\n'} }
    method key -->Key     { $self.${cut -f1 | tr -d '\n'} }
    method JSON { $self-->List[Pair].JSON }
}

augment List[Pair] {
    method keys-->List[Elem-Type[0]]  { $self.${cut -f1} }
    method values-->List[Elem-Type[1]] { $self.${cut -f2-} }
    method JSON {
        (
            '{' ~
            ('"' ~ .key ~ '":"' ~ .value ~ '"' for @$self).join(',') ~
            '}'
        )-->JSON
    }

    method at-key($key)-->Elem-Type[1] {
        $self.${
            awk :$key '-F\t'
            '$1==ENVIRON["key"]{printf "%s",substr($0,index($0,FS)+1);exit}'
        }
    }

    method key-for($value) -->Elem-Type[0] {
        $self.${
            awk :$value '-F\t'
            ｢$2==ENVIRON["value"]{ printf "%s", $1; exit }｣
        }
    }


constant $set-key =
｢{if($1==ENVIRON["key"]){
  printf "%s\t%s\n", $1,ENVIRON["value"]; found=1
 } else {
  print
}}
END{if(!found){ printf "%s\t%s\n", ENVIRON["key"],ENVIRON["value"]}}｣;

    method set-key($key, $value) is rw {
        $self.${ awk :$key :$value '-F\t' $set-key }
    }

    method delete-key($key) is rw {
        $self.${ awk :$key '-F\t' '$1 != ENVIRON["key"] { print }' }
    }

    method exists-key($key)?  {
        $self.${
            awk :$key '-F\t'
            '$1==ENVIRON["key"]{ found=1; exit } END { if(!found) exit 1 }'
        }
    }
}
