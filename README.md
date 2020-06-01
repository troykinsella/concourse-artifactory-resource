# concourse-artifactory-resource

A Concourse CI resource for publishing generic artifacts to Artifactory.

One of the following version strategies can be configured:

| Version Strategy | Description |
| --- | --- |
| `none`   | The resource does not manipulate any versions. The `check` and `in` operations are no-ops, and the `put` operation allows you to publish one or more files to a repository path. This configuration is suitable for simply publishing files to Artifactory, but it not suitable if any downstream jobs need to react (i.e. `trigger: true`) to changes to a published file.
| `multi-file` | Lists files matching a glob pattern in a repository, and extracts the version from the file name using a regex. This strategy is appropriate when publications create new files that do not overwrite existing files, and the file names contain a version.
| `single-file` | This strategy treats a changing sha256 sum of a single file as a version stream. This is appropriate when only a single file name is manipulated, and a publication can overwrite a previous one of the same name/path.


## Source Configuration

General attributes:

* `url`: Required. The URL at which the Artifactory instance can be reached. Example: `https://tools.example.com/artifactory`.
* `repository`: Required. The name of the generic repository in Artifactory. Example: `generic-local`.
* `api_key`: Required. The API key with which to publish artifacts.
* `version_strategy`: Optional. The strategy by which to handle versioning. Default: `none`.

Version strategy-specific attributes:

* `none`:
  * `path`: Optional. Denotes a directory path under the `repository` in which files will be published.
* `multi-file`:
  * `file_pattern`: Optional. Default: `.*`. The regex with which to filter a listing of files in the `source.repository` directory.
    Useful when a repository contains a mixed set of artifacts, and this resource needs to operate on a single version line according
    to a file naming pattern.
  * `path`: Optional. The path to the directory in which artifact files can be located, relative to `repository`.
  * `version_pattern`: Required. The regex with which to extract a version from an artifact file name.
    Example: `[0-9]+[.][0-9]+[.][0-9]+`.
* `single-file`:
  * `path`: Required. The path to the single file to manipulate, relative to `repository`.

## Behaviour

### `check`

The behaviour depends on the configured `version_strategy`:
* `none`: No-op.
* `multi-file`: Checks for artifact versions by listing the `source.repository` directory, filtering the file list with
  `source.file_pattern` and extracting versions using `source.version_pattern`.
* `single-file`: Checks the `sha256sum` value of the configured file, and treats it as the version.

### `in`

The behaviour depends on the configured `version_strategy`:
* `none`: No-op.
* `multi-file`: Fetch the artifact file having the expected version number in the name. 
* `single-file`: Fetch the latest artifact file, validating the expected `sha256sum` version produced by `check`.
  As Artifactory does not support a "file change history" API, only the latest file publication can be understood by this configuration,
  which means that it cannot operate on `every` changed version.

#### Parameters

General parameters:

* `skip_download`: Optional. Default: `false`. Do not download the artifact file when `true`. Does nothing
  with the `none` version strategy.

### `out`: Publish artifacts to Artifactory

The behaviour depends on the configured `version_strategy`:
* `none`: Any files found in the `param.files` directory that match the optional `glob` pattern 
  will be published to the given `source.path` under the `source.repository` in Artifactory.
* `multi-file`: A single file supplied in the `files.path` parameter, matching the `source.file_pattern`, and having a
  version that can be extracted with `source.version_pattern` will be published to the given 
  `source.path` under the `source.repository` in Artifactory.
* `single-file`: A single file supplied in the `files.path` parameter, having the basename of `source.path` will 
  be published to the given `source.path` under the `source.repository` in Artifactory.

#### Parameters

General parameters:

* `files`: Required. The path to a directory containing files to publish.

Version strategy-specific parameters:

* `none`:
  * `glob`: Optional. Default: `*`. A glob expression of the file names to match
  for publication. Only relevant to the `none` version strategy.

## Examples

### Resource Type

```yaml
resource_types:
- name: generic-artifact
  type: docker-image
  source:
    repository: troykinsella/concourse-artifactory-resource
    tag: latest
```

### Version Strategy: `none`

In this example, a task prepares one or more files that can all be published at the same time. Doing a `get` 
on the `artifact` resource is not a requirement.

```yaml
resources:
- name: artifact
  type: generic-artifact
  source:
    url: https://tools.example.com/artifactory
    repository: generic-local
    api_key: asdf
    path: project-A

jobs:
- name: publish-source
  plan:
  - get: master # git resource
    trigger: true
  - task: archive source
    file: tasks/archive-source.yml
    input_mapping:
      source: master
    output_mapping:
      archive: files-to-publish
  - put: artifact
    params:
      files: files-to-publish
      glob: "*.tar.gz"
```

### Version Strategy: `multi-file`

In this example, a task prepares a file to publish which conforms to the artifact naming pattern,
and embeds the relevant version in the file name. In this case, the version came from a `version` resource.

```yaml
resources:
- name: artifact
  type: generic-artifact
  source:
    version_strategy: multi-file
    url: https://tools.example.com/artifactory
    repository: generic-local
    api_key: asdf
    path: path/to/dir
    file_pattern: 'foo-.*'
    version_pattern: '[0-9]+[.][0-9]+[.][0-9]+'

jobs:
- name: publish-source
  plan:
  - in_parallel:
    - get: master # git resource
      trigger: true
    - get: version # version resource
  - task: archive source # This produces a file named foo-1.2.3.tar.gz
    file: tasks/archive-source.yml
    input_mapping:
      source: master
      version: version
    output_mapping:
      archive: file-to-publish
  - put: artifact
    params:
      files: files-to-publish
```

### Version Strategy: `single-file`

In this example, a job is triggered upon an artifact publication that overwrote
a previous one.

```yaml
resources:
- name: artifact
  type: generic-artifact
  source:
    version_strategy: single-file
    url: https://tools.example.com/artifactory
    repository: generic-local
    api_key: asdf
    path: path/to/file.tar.gz

jobs:
- name: verify-archive
  plan:
  - get: artifact
    trigger: true
  - task: verify archive
    file: tasks/verify-archive.yml
    input_mapping:
      files: artifact
    params:
      FILE: file.tar.gz
```

## License

MIT © Troy Kinsella
