require 'fileutils'
require 'spec_helper'
require 'open3'
require 'json'

describe "commands:out" do

  let(:out_file) { '/opt/resource/out' }
  let(:mockeltonfile) { '/resource/Mockletonfile' }
  let(:mockelton_out) { '/resource/mockleton.out' }
  let(:param_files) { 'some_files' }

  before(:each) do
    Dir.mkdir(param_files)
  end

  after(:each) do
    FileUtils.rm_rf mockeltonfile
    FileUtils.rm_rf mockelton_out
    FileUtils.rm_rf param_files
  end

  it "should exist" do
    expect(File).to exist(out_file)
    expect(File.stat(out_file).mode.to_s(8)[3..5]).to eq("755")
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
        "params" => {
          "files" => param_files
        },
      }.to_json

      stdout, stderr, status = Open3.capture3("#{out_file} .", :stdin_data => stdin)
      expect(status.success?).to be false

      expect(stderr).to eq "unrecognized version strategy: bogus\n"
    end

  end

  it "should error upon no glob matches" do
    stdin = {
      "source" => {
        "url" => "https://artifactory",
        "repository" => "generic-local",
        "api_key" => "foo",
        "path" => "path/to/file.tar.gz"
      },
      "params" => {
        "files" => param_files
      },
    }.to_json

    stdout, stderr, status = Open3.capture3("#{out_file} .", :stdin_data => stdin)
    expect(status.success?).to be false

    expect(stderr).to eq "glob param did not match any files in path: ./#{param_files}\n"
  end

  describe "no version strategy" do

    it "should return an empty version" do
      prep_curl_stub '""'

      stdin = {
        "source" => {
          "url" => "https://artifactory",
          "repository" => "generic-local",
          "api_key" => "foo",
          "path" => "path"
        },
        "params" => {
          "files" => param_files
        },
      }.to_json

      File.write(File.join(param_files, 'file.tar.gz'), "foo")

      stdout, stderr, status = Open3.capture3("#{out_file} .", :stdin_data => stdin)

      expect(status.success?).to be true

      out = JSON.parse(File.read(mockelton_out))

      expect(out["sequence"].size).to be 1
      expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                              "curl",
                                                              "--fail",
                                                              "-L",
                                                              "-X", "PUT",
                                                              "-H", "X-JFrog-Art-Api: foo",
                                                              "-H", "X-Checksum-Sha1: 0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33",
                                                              "-H", "X-Checksum-Sha256: 2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae",
                                                              "-H", "X-Checksum-Md5: acbd18db4cc2f85cedef654fccc4a4d8",
                                                              "-T", "file.tar.gz",
                                                              "https://artifactory/generic-local/path/file.tar.gz"
                                                            ]

      expect(stdout).to eq "{\"version\":{}}\n"
    end

  end

  describe "single file version strategy" do

    it "should return a version" do
      prep_curl_stub '""'

      stdin = {
        "source" => {
          "version_strategy" => "single-file",
          "url" => "https://artifactory",
          "repository" => "generic-local",
          "api_key" => "foo",
          "path" => "path/to/file.tar.gz"
        },
        "params" => {
          "files" => param_files
        },
      }.to_json

      File.write(File.join(param_files, 'file.tar.gz'), "foo")

      stdout, stderr, status = Open3.capture3("#{out_file} .", :stdin_data => stdin)

      expect(status.success?).to be true

      out = JSON.parse(File.read(mockelton_out))

      expect(out["sequence"].size).to be 1
      expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                              "curl",
                                                              "--fail",
                                                              "-L",
                                                              "-X", "PUT",
                                                              "-H", "X-JFrog-Art-Api: foo",
                                                              "-H", "X-Checksum-Sha1: 0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33",
                                                              "-H", "X-Checksum-Sha256: 2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae",
                                                              "-H", "X-Checksum-Md5: acbd18db4cc2f85cedef654fccc4a4d8",
                                                              "-T", "file.tar.gz",
                                                              "https://artifactory/generic-local/path/to/file.tar.gz"
                                                            ]

      expect(stdout).to eq <<~EOF
        {
          "version": {
            "sha256": "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"
          }
        }
      EOF
    end

  end

end
