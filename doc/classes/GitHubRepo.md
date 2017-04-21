# GitHubRepo
 GitHubRepo represents a github repo name like `nodejs/node`.
## GitURL
>method GitURL( ⟶ [GitURL](./GitURL.md))

 Long form of `.url`
## clone
>method clone([Str](./Str.md) **:$to** ⟶ [File](./File.md))

 Clones the GitHubRepo.
```perl6
GitHubRepo<spitsh/spitsh/>.clone.cd;
say ${ $*git status };
```

|Parameter|Description|
|---------|-----------|
|**:$to**| Path to clone the repo to|
## name
>method name( ⟶ [Str](./Str.md))

 Returns the name part of the GitHubRepo.
```perl6
 say GitHubRepo<nodejs/node>.name #-> node
```
## owner
>method owner( ⟶ [Str](./Str.md))

 Returns the owner part of the GitHubRepo.
```perl6
 say GitHubRepo<nodejs/node>.owner #-> nodejs
```
## url
>method url( ⟶ [GitURL](./GitURL.md))

 Returns the https url for the repo
```perl6
 GitHubRepo<nodejs/node>.url #-> https://github.com/nodejs/node.git
```
