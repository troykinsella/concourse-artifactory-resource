# concourse-artifactory-resource

A Concourse CI resource for publishing generic artifacts to Artifactory.

One of the following version strategies can be configured:

| Version Strategy | Description |
| --- | --- |
| `none`   | The resource does not manipulate any versions. The `check` and `in` operations are no-ops, and the `put` operation allows you to publish one or more files to a repository path. This configuration is suitable for simply publishing files to Artifactory, but it not suitable if any downstream jobs need to react (i.e. `trigger: true`) to changes to a published file. 
| `single-file` | This strategy treats a changing sha256 sum of a single file as a version stream. This is appropriate when only a single file name is manipulated, and a publication can overwrite a previous one of the same name/path.


## Source Configuration

* `url`: Required. The URL at which the Artifactory instance can be reached. Example: `https://tools.example.com/artifactory`.
* `repository`: Required. The name of the generic repository in Artifactory. Example: `generic-local`.
* `api_key`: Required. The API key with which to publish artifacts.
* `version_strategy`: Optional. The strategy by which to handle versioning. Default: `none`.
* `path`: When the `version_strategy` is:
  * `none`: Optional. Denotes a directory path under the `repository` in which files will be published.
  * `single-file`: Required. The path to the single file to manipulate, relative to `repository`.

## Behaviour

### `check`

The behaviour depends on the configured `version_strategy`:
* `none`: No-op.
* `single-file`: Checks the `sha256sum` value of the configured file, and treats it as the version.

### `in`

The behaviour depends on the configured `version_strategy`:
* `none`: No-op.
* `single-file`: Fetch the latest artifact file, validating the expected `sha256sum` version produced by `check`.
  As Artifactory does not support a "file change history" API, only the latest file publication can be understood by this configuration,
  which means that it cannot operate on `every` changed version.

#### Parameters

* `skip_download`: Optional. Default: `false`. Do not download the artifact file when `true`.

### `out`: Publish artifacts to Artifactory

The behaviour depends on the configured `version_strategy`:
* `none`: Any files found in the `param.files` directory that match the optional `glob` pattern 
  will be published to the given `source.path` under the `source.repository` in Artifactory.
* `single-file`: A single file named `source.path` 

#### Parameters

* `files`: Required. The path to a directory containing files to publish.
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
- name: 
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

### Version Strategy: `single-file`

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
- name: 
  plan:
  - get: artifact
    trigger: true
  - task: do something with archive
    file: tasks/do-something.yml
    input_mapping:
      files: artifact
    params:
      FILE: file.tar.gz
```

## License

MIT © Troy Kinsella
