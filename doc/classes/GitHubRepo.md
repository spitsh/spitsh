# GitHub
 GitHub represents a github repo name like `nodejs/node`.
## GitURL
>method GitURL( ⟶ [GitURL](./GitURL.md))

 Long form of `.url`
## clone
>method clone([Str](./Str.md) **:$to** ⟶ [File](./File.md))

 Clones the GitHub.
```perl6
GitHub<spitsh/spitsh>.clone.cd;
say ${ $*git status };
```

|Parameter|Description|
|---------|-----------|
|**:$to**| Path to clone the repo to|
## name
>method name( ⟶ [Str](./Str.md))

 Returns the name part of the GitHub.
```perl6
 say GitHub<nodejs/node>.name #-> node
```
## owner
>method owner( ⟶ [Str](./Str.md))

 Returns the owner part of the GitHub.
```perl6
 say GitHub<nodejs/node>.owner #-> nodejs
```
## url
>method url( ⟶ [GitURL](./GitURL.md))

 Returns the https url for the repo
```perl6
 GitHub<nodejs/node>.url #-> https://github.com/nodejs/node.git
```
