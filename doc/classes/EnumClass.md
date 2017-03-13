# EnumClass
 EnumClass is the base class used to create hierarchical enums. The only example in Spitsh of this is the OS EnumClass which stores the relationships between Operating Systems.
## has-member
>method has-member([Str](./Str.md) **$enum** ⟶ [Bool](./Bool.md))


 Returns true if the argument string exactly matches a member of the enum class. `~~` will call this method internally.
```perl6
say Debian.has-member('Ubuntu'); # true
say RHEL.has-member('Ubuntu'); # false
say Ubuntu ~~ Debian; # true
```

|Parameter|Description|
|---------|-----------|
|**$enum**| A string to match against the enum's members|
## name
>method name( ⟶ [Str](./Str.md))


 Returns the name of the enum class.
