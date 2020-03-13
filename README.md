# concourse-artifactory-resource

A Concourse CI resource for publishing generic artifacts to Artifactory.

Artifacts are published using a `curl` `PUT` along with a 
`X-JFrog-Art-Api` header to supply the API key. 

## Source Configuration

* `repository`: Required. The URL at which the generic repository in Artifactory 
   can be located. Example: `https://tools.example.com/artifactory/generic-local`.
* `api_key`: Required. The API key with which to publish artifacts.
* `path`: Optional. A path under the repository URL in which artifacts will be
  published.

### Example

```yaml
resource_types:
- name: generic-artifact
  type: docker-image
  source:
    repository: troykinsella/concourse-artifactory-resource
    tag: latest

resources:
- name: artifact
  type: generic-artifact
  source:
    repository: https://tools.example.com/artifactory/generic-local
    api_key: asdf
    path: project-A
```


## Behaviour

### `check`: No-Op

### `in`: No-Op

### `out`: Publish artifacts to Artifactory

#### Parameters

* `files`: Optional. The path to a directory containing files to publish.
* `glob`: Optional. Default: `*`. A glob expression of the file names to match
  for publication.

#### Example

```yaml
# Extends example in Source Configuration

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

## License

MIT © Troy Kinsella
