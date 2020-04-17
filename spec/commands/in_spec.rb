require 'fileutils'
require 'spec_helper'
require 'open3'
require 'json'

describe "commands:in" do

  let(:in_file) { '/opt/resource/in' }
  let(:mockeltonfile) { '/resource/Mockletonfile' }
  let(:mockelton_out) { '/resource/mockleton.out' }

  after(:each) do
    FileUtils.rm_rf mockeltonfile
    FileUtils.rm_rf mockelton_out
  end

  it "should exist" do
    expect(File).to exist(in_file)
    expect(File.stat(in_file).mode.to_s(8)[3..5]).to eq("755")
  end

  describe "no version strategy" do

    it "should return an empty version" do
      stdin = {
        "source" => {
          "url" => "https://artifactory",
          "repository" => "generic-local",
          "api_key" => "foo",
          "path" => "path/to/file.tar.gz"
        },
        "version" => {
          "sha256" => "abc"
        }
      }.to_json

      stdout, stderr, status = Open3.capture3("#{in_file} .", :stdin_data => stdin)
      expect(status.success?).to be true

      expect(stdout).to eq "{\"version\":{}}\n"
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
        "version" => {
          "sha256" => "abc"
        }
      }.to_json

      stdout, stderr, status = Open3.capture3("#{in_file} .", :stdin_data => stdin)
      expect(status.success?).to be false

      expect(stderr).to eq "unrecognized version strategy: bogus\n"
    end

  end


  describe "single file version strategy" do

    it "errors on non-existent version" do
      stdin = {
        "source" => {
          "version_strategy" => "single-file",
          "url" => "https://artifactory",
          "repository" => "generic-local",
          "api_key" => "foo",
          "path" => "path/to/file.tar.gz"
        },
        "version" => {
          "sha256" => "d73679c6aa31eea5df0bddaa541d7b849b4ab51f21bedc0ced23ddd9ab124690"
        },
        "params" => {}
      }.to_json

      stdout, stderr, status = Open3.capture3("#{in_file} .", :stdin_data => stdin)

      expect(status.success?).to be false
      expect(stderr).to eq "version unavailable: d73679c6aa31eea5df0bddaa541d7b849b4ab51f21bedc0ced23ddd9ab124690\n"
    end

    it "downloads existing version" do
      prep_curl_stub2(load_fixture('file_info.json'), '""')

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
        },
        "params" => {}
      }.to_json

      stdout, stderr, status = Open3.capture3("#{in_file} .", :stdin_data => stdin)

      expect(status.success?).to be true
      out = JSON.parse(File.read(mockelton_out))
      expect(out["sequence"].size).to be 2
      expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                              "curl",
                                                              "-fSsL",
                                                              "-H", "X-JFrog-Art-Api: foo",
                                                              "https://artifactory/api/storage/generic-local/path/to/file.tar.gz"
                                                            ]
      expect(out["sequence"][1]["exec-spec"]["args"]).to eq [
                                                              "curl",
                                                              "-fL",
                                                              "-H", "X-JFrog-Art-Api: foo",
                                                              "-o", "file.tar.gz",
                                                              "https://artifactory/generic-local/path/to/file.tar.gz"
                                                            ]

      expect(stdout).to eq <<~EOF
        {
          "version": {
            "sha256": "d73679c6aa31eea5df0bddaa541d7b849b4ab51f21bedc0ced23ddd9ab124691"
          }
        }
      EOF

      expect(File.read("version")).to eq "d73679c6aa31eea5df0bddaa541d7b849b4ab51f21bedc0ced23ddd9ab124691\n"
    end


    it "skips download" do
      prep_curl_stub(load_fixture('file_info.json'))

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
        },
        "params" => {
          "skip_download" => true
        }
      }.to_json

      stdout, stderr, status = Open3.capture3("#{in_file} .", :stdin_data => stdin)

      expect(status.success?).to be true
      out = JSON.parse(File.read(mockelton_out))
      expect(out["sequence"].size).to be 1
      expect(out["sequence"][0]["exec-spec"]["args"]).to eq [
                                                              "curl",
                                                              "-fSsL",
                                                              "-H", "X-JFrog-Art-Api: foo",
                                                              "https://artifactory/api/storage/generic-local/path/to/file.tar.gz"
                                                            ]

      expect(stdout).to eq <<~EOF
        {
          "version": {
            "sha256": "d73679c6aa31eea5df0bddaa541d7b849b4ab51f21bedc0ced23ddd9ab124691"
          }
        }
      EOF

      expect(File.read("version")).to eq "d73679c6aa31eea5df0bddaa541d7b849b4ab51f21bedc0ced23ddd9ab124691\n"
    end

  end

end
