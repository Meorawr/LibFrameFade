# LibFrameFade

LibFrameFade is a library that attempts to resolve UIFrameFade taint by reimplementing it to use the UI widget animation framework.

## Embedding

The library may be imported as an external in a `.pkgmeta` file as shown below, through the use of a Git submodule, or by downloading an existing packaged release and copying it into your addon folder.

```yaml
externals:
  Libs/LibFrameFade: https://github.com/Meorawr/LibFrameFade
```

To load the library include a reference to the `lib.xml` file either within your TOC or through an XML Include element.

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <Include file="Libs\LibFrameFade\lib.xml"/>
</Ui>
```

The library can also be installed as a standalone addon, and consumers can add an optional dependency to their TOC file to load any disembedded versions prior to their own addon.

## License

The library is released under the terms of the [Unlicense](https://unlicense.org/), a copy of which can be found in the `LICENSE` document at the root of the repository.

## Contributors

* [Daniel "Meorawr" Yates](https://github.com/meorawr)
