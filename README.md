# KResource

KResource is a pure-Swift library for iOS resource encryption.

## Requirements

- iOS 11.0+
- Swift 5.0+

## Installation

### Swift Package Manager

- File > Swift Packages > Add Package Dependency
- Add `https://github.com/K999999999/KResource.git`
- Select "Up to Next Major" with "0.0.1" < "1.0.0"

## Usage

### Script

First, add `run script` in `Build Phases` to encrypt resources

```
${BUILD_DIR%Build/*}SourcePackages/checkouts/KResource/KResource/KEncrypter a.bundle b.bundle c.bundle
```

- use `-e` or `--encrypt` to set encrypt key, default is `PRODUCT_BUNDLE_IDENTIFIER`

```
${BUILD_DIR%Build/*}SourcePackages/checkouts/KResource/KResource/KEncrypter a.bundle b.bundle c.bundle -e 123456789
```

```
KResource.resource.encrypt = "123456789"
```

- use `-o` or `--output` to set output file name, default is `EXECUTABLE_NAME.resource`

```
${BUILD_DIR%Build/*}SourcePackages/checkouts/KResource/KResource/KEncrypter a.bundle b.bundle c.bundle -e 123456789 -o a.data
```

```
KResource.resource.encrypt = "123456789"
KResource.resource.output = "a.data"
```

### Usage example

```
import KResource

let a = KResource.resource(forResource: "a", withExtension: "bundle")!

// get data of a.bundle/a
let data = try? a.a.data()

// get contents of a.bundle/b/
let contents = try? a.b.contentsOfDirectory()

// get kind of a.bundle/c
let kind = a.c.kind()

// get image of a.bundle/d@3x.png
let image = a.d.image()

// register all fonts in a.bundle
try? a.registerAllFonts()

// get jsonObject of a.bundle/e.json
let jsonObject = try? a.e.jsonObject()

// get fileURL of a.bundle/f.mp4
let fileURL = try? a.f.videoFileURL()

// a func to get file data in a.bundle
func data(name: String) throws -> Data { try a[name].data() }
```
