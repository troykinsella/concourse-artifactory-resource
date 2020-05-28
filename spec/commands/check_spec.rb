require 'fileutils'
require 'spec_helper'
require 'open3'
require 'json'

describe "commands:check" do

  let(:check_file) { '/opt/resource/check' }
  let(:mockeltonfile) { '/resource/Mockletonfile' }
  let(:mockelton_out) { '/resource/mockleton.out' }

  after(:each) do
    FileUtils.rm_rf mockeltonfile
    FileUtils.rm_rf mockelton_out
  end

  it "should exist" do
    expect(File).to exist(check_file)
    expect(File.stat(check_file).mode.to_s(8)[3..5]).to eq("755")
  end

  describe "no version strategy" do

    it "should return an empty array" do
      stdin = {
        "source" => {
          "version_strategy" => "none",
          "url" => "https://artifactory",
          "repository" => "generic-local",
          "api_key" => "foo",
          "path" => "path/to/file.tar.gz"
        },
      }.to_json

      stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)
      expect(status.success?).to be true
      expect(stdout).to eq "[]\n"
    end

  end

  describe "unsupported version strategy" do

    it "errors" do

      stdin = {
        "source" => {
          "version_strategy" => "bogus",
          "url" => "https://artifactory",
          "repository" => "generic-local",
          "api_key" => "foo",
          "path" => "path/to/file.tar.gz"
        },
      }.to_json

      stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

      expect(status.success?).to be false
      expect(stderr).to eq "unrecognized version strategy: bogus\n"
    end

  end

  describe "single file version strategy" do

    it "returns empty version on 404" do
      prep_curl_stub_with_status("", 404)

      stdin = {
        "source" => {
          "version_strategy" => "single-file",
          "url" => "https://artifactory",
          "repository" => "generic-local",
          "api_key" => "foo",
          "path" => "path/to/file.tar.gz"
        },
      }.to_json

      stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

      expect(status.success?).to be true

      out = JSON.parse(File.read(mockelton_out))

      expect(out["sequence"].size).to be 1
      expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                              "curl",
                                                              "-SsLk",
                                                              "--write-out", '\n%{http_code}\n',
                                                              "-H", "X-JFrog-Art-Api: foo",
                                                              "https://artifactory/api/storage/generic-local/path/to/file.tar.gz"
                                                            ]

      expect(stdout).to eq "[]\n"
    end

    it "returns error on failure status code" do
      prep_curl_stub_with_status("", 500)

      stdin = {
        "source" => {
          "version_strategy" => "single-file",
          "url" => "https://artifactory",
          "repository" => "generic-local",
          "api_key" => "foo",
          "path" => "path/to/file.tar.gz"
        },
      }.to_json

      stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

      expect(status.success?).to be false
      expect(stdout).to eq ""
      expect(stderr).to eq "HTTP API request failed with status code: 500\n"
    end

    describe "on first run" do

      it "returns new version" do
        prep_curl_stub_with_status(load_fixture('file_info.json'), 200)

        stdin = {
          "source" => {
            "version_strategy" => "single-file",
            "url" => "https://artifactory",
            "repository" => "generic-local",
            "api_key" => "foo",
            "path" => "path/to/file.tar.gz"
          },
        }.to_json

        stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

        expect(status.success?).to be true

        out = JSON.parse(File.read(mockelton_out))

        expect(out["sequence"].size).to be 1
        expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                                "curl",
                                                                "-SsLk",
                                                                "--write-out", '\n%{http_code}\n',
                                                                "-H", "X-JFrog-Art-Api: foo",
                                                                "https://artifactory/api/storage/generic-local/path/to/file.tar.gz"
                                                              ]

        expect(stdout).to eq <<~EOF
          [
            {
              "sha256": "d73679c6aa31eea5df0bddaa541d7b849b4ab51f21bedc0ced23ddd9ab124691"
            }
          ]
        EOF
      end
    end

    describe "on second run" do

      it "returns existing version" do
        prep_curl_stub_with_status(load_fixture('file_info.json'), 200)

        stdin = {
          "source" => {
            "version_strategy" => "single-file",
            "url" => "https://artifactory",
            "repository" => "generic-local",
            "api_key" => "foo",
            "path" => "path/to/file.tar.gz"
          },
          "version" => {
            "sha256" => "d73679c6aa31eea5df0bddaa541d7b849b4ab51f21bedc0ced23ddd9ab124691"
          }
        }.to_json

        stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

        expect(status.success?).to be true

        out = JSON.parse(File.read(mockelton_out))

        expect(out["sequence"].size).to be 1
        expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                                "curl",
                                                                "-SsLk",
                                                                "--write-out", '\n%{http_code}\n',
                                                                "-H", "X-JFrog-Art-Api: foo",
                                                                "https://artifactory/api/storage/generic-local/path/to/file.tar.gz"
                                                              ]

        expect(stdout).to eq <<~EOF
          [
            {
              "sha256": "d73679c6aa31eea5df0bddaa541d7b849b4ab51f21bedc0ced23ddd9ab124691"
            }
          ]
        EOF
      end

      it "returns new version" do
        prep_curl_stub_with_status(load_fixture('file_info.json'), 200)

        stdin = {
          "source" => {
            "version_strategy" => "single-file",
            "url" => "https://artifactory",
            "repository" => "generic-local",
            "api_key" => "foo",
            "path" => "path/to/file.tar.gz"
          },
          "version" => {
            "sha256" => "0"
          }
        }.to_json

        stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

        expect(status.success?).to be true

        out = JSON.parse(File.read(mockelton_out))

        expect(out["sequence"].size).to be 1
        expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                                "curl",
                                                                "-SsLk",
                                                                "--write-out", '\n%{http_code}\n',
                                                                "-H", "X-JFrog-Art-Api: foo",
                                                                "https://artifactory/api/storage/generic-local/path/to/file.tar.gz"
                                                              ]

        expect(stdout).to eq <<~EOF
          [
            {
              "sha256": "d73679c6aa31eea5df0bddaa541d7b849b4ab51f21bedc0ced23ddd9ab124691"
            }
          ]
        EOF
      end

    end

  end

  describe "multi file version strategy" do

    it "requires version_pattern source attribute" do
      prep_curl_stub_with_error("curl had a bad day", 1)

      stdin = {
        "source" => {
          "version_strategy" => "multi-file",
          "url" => "https://artifactory",
          "repository" => "generic-local",
          "api_key" => "foo",
          "path" => "path"
        },
      }.to_json

      stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

      expect(status.success?).to be false
      expect(stdout).to eq ""
      expect(stderr).to eq "must supply 'version_pattern' source attribute\n"
    end

    it "returns error on http failure" do
      prep_curl_stub_with_error("curl had a bad day", 1)

      stdin = {
        "source" => {
          "version_strategy" => "multi-file",
          "url" => "https://artifactory",
          "repository" => "generic-local",
          "api_key" => "foo",
          "path" => "path",
          "version_pattern" => "[0-9]+"
        },
      }.to_json

      stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

      expect(status.success?).to be false
      expect(stdout).to eq ""
      expect(stderr).to eq "curl had a bad day\n"
    end

    describe "on first run" do

      it "returns latest version" do
        prep_curl_stub(load_fixture('file_list.json'))

        stdin = {
          "source" => {
            "version_strategy" => "multi-file",
            "url" => "https://artifactory",
            "repository" => "generic-local",
            "api_key" => "foo",
            "path" => "path",
            "version_pattern" => "[0-9]+[.][0-9]+[.][0-9]+"
          }
        }.to_json

        stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

        expect(status.success?).to be true

        out = JSON.parse(File.read(mockelton_out))

        expect(out["sequence"].size).to be 1
        expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                                "curl",
                                                                "-fSsL",
                                                                "-H", "X-JFrog-Art-Api: foo",
                                                                "https://artifactory/api/storage/generic-local/path"
                                                              ]

        expect(stdout).to eq <<~EOF
            [
              {
                "number": "2.0.0"
              }
            ]
        EOF
      end

    end

    describe "when no new version available" do

      it "returns latest version" do
        prep_curl_stub(load_fixture('file_list.json'))

        stdin = {
          "source" => {
            "version_strategy" => "multi-file",
            "url" => "https://artifactory",
            "repository" => "generic-local",
            "api_key" => "foo",
            "path" => "path",
            "version_pattern" => "[0-9]+[.][0-9]+[.][0-9]+"
          },
          "version" => {
            "number" => "2.0.0"
          }
        }.to_json

        stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

        expect(status.success?).to be true

        out = JSON.parse(File.read(mockelton_out))

        expect(out["sequence"].size).to be 1
        expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                                "curl",
                                                                "-fSsL",
                                                                "-H", "X-JFrog-Art-Api: foo",
                                                                "https://artifactory/api/storage/generic-local/path"
                                                              ]

        expect(stdout).to eq <<~EOF
            [
              {
                "number": "2.0.0"
              }
            ]
        EOF
      end

      it "respects file_pattern" do
        prep_curl_stub(load_fixture('file_list.json'))

        stdin = {
          "source" => {
            "version_strategy" => "multi-file",
            "url" => "https://artifactory",
            "repository" => "generic-local",
            "api_key" => "foo",
            "path" => "path",
            "file_pattern" => "foo-.*",
            "version_pattern" => "[0-9]+[.][0-9]+[.][0-9]+"
          }
        }.to_json

        stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

        expect(status.success?).to be true

        out = JSON.parse(File.read(mockelton_out))

        expect(out["sequence"].size).to be 1
        expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                                "curl",
                                                                "-fSsL",
                                                                "-H", "X-JFrog-Art-Api: foo",
                                                                "https://artifactory/api/storage/generic-local/path"
                                                              ]

        expect(stdout).to eq <<~EOF
            [
              {
                "number": "1.1.0"
              }
            ]
        EOF
      end

    end

    describe "when new version available" do

      it "returns all versions" do
        prep_curl_stub(load_fixture('file_list.json'))

        stdin = {
          "source" => {
            "version_strategy" => "multi-file",
            "url" => "https://artifactory",
            "repository" => "generic-local",
            "api_key" => "foo",
            "path" => "path",
            "version_pattern" => "[0-9]+[.][0-9]+[.][0-9]+"
          },
          "version" => {
            "number" => "1.0.0"
          }
        }.to_json

        stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

        expect(status.success?).to be true

        out = JSON.parse(File.read(mockelton_out))

        expect(out["sequence"].size).to be 1
        expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                                "curl",
                                                                "-fSsL",
                                                                "-H", "X-JFrog-Art-Api: foo",
                                                                "https://artifactory/api/storage/generic-local/path"
                                                              ]

        expect(stdout).to eq <<~EOF
            [
              {
                "number": "1.0.0"
              },
              {
                "number": "1.0.1"
              },
              {
                "number": "1.1.0"
              },
              {
                "number": "2.0.0"
              }
            ]
        EOF
      end

      it "respects file_pattern" do
        prep_curl_stub(load_fixture('file_list.json'))

        stdin = {
          "source" => {
            "version_strategy" => "multi-file",
            "url" => "https://artifactory",
            "repository" => "generic-local",
            "api_key" => "foo",
            "path" => "path",
            "file_pattern" => "foo-.*",
            "version_pattern" => "[0-9]+[.][0-9]+[.][0-9]+"
          },
          "version" => {
            "number" => "1.0.0"
          }
        }.to_json

        stdout, stderr, status = Open3.capture3("#{check_file} .", :stdin_data => stdin)

        expect(status.success?).to be true

        out = JSON.parse(File.read(mockelton_out))

        expect(out["sequence"].size).to be 1
        expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                                "curl",
                                                                "-fSsL",
                                                                "-H", "X-JFrog-Art-Api: foo",
                                                                "https://artifactory/api/storage/generic-local/path"
                                                              ]

        expect(stdout).to eq <<~EOF
            [
              {
                "number": "1.0.0"
              },
              {
                "number": "1.0.1"
              },
              {
                "number": "1.1.0"
              }
            ]
        EOF
      end

    end

  end

end
