# GitURL
 GitURL represents something that can be passed to `git clone`.
## clone
>method clone([Str](./Str.md) **:$to** ⟶ [File](./File.md))

 Calls `git clone` on the the url and returns the path to the cloned directory.
```perl6
GitURL<https://github.com/spitsh/spitsh.git/>.clone.cd;
say ${ $*git status };
```

|Parameter|Description|
|---------|-----------|
|**:$to**| Path to clone the repo to|
## name
>method name( ⟶ [Str](./Str.md))

 Gets the last section of the url without its extension. This is the same as directory name git will use to clone into by default.
```perl6
 say GitURL<https://github.com/nodejs/node.git>.name #->node
```
