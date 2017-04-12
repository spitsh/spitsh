# Bool
 Bool refers to the Boolean type. They can be used as values but more often represent whether a shell command exited successfully. In [Str](Str.md) context a Bool will be '1' if true and "" (they empty string) if false.
```perl6
say True.WHAT #-> Bool
say False.WHAT #-> Bool
say ("foo" eq "bar").WHAT; #-> Bool
say False; #-> ''
say True;  #-> '1'
```
## ACCEPTS
>method ACCEPTS([Str](./Str.md) **$b** ⟶ [Bool](./Bool.md))


 Simply returns the value of the invocant regardless of the argument.
## Int
>method Int( ⟶ [Int](./Int.md))


 In Int context, Bools become a 1 if True or a 0 if False.
## gist
>method gist( ⟶ [Str](./Str.md))


 .gist returns "True" or "False".
