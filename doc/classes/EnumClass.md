# EnumClass
 EnumClass is the base class used to create hierarchical enums. The only example in Spitsh of this is the OS EnumClass which stores the relationships between Operating Systems.
## ACCEPTS
>method ACCEPTS([EnumClass](./EnumClass.md) **$b** ⟶ [Bool](./Bool.md))


 Returns True if the argument EnumClass is a member of the invocant EnumClass.
## has-member
>method has-member([Str](./Str.md) **$candidate** ⟶ [Bool](./Bool.md))


 Returns true if the argument string exactly matches a member of the enum class.
```perl6
say Debian.has-member('Ubuntu'); # true
say RHEL.has-member('Ubuntu'); # false
say Ubuntu ~~ Debian; # true
```

|Parameter|Description|
|---------|-----------|
|**$candidate**| A string to match against the enum's members|
## name
>method name( ⟶ [Str](./Str.md))


 Returns the name of the enum class.
