#!/usr/bin/env ruby

require 'csv'
require 'json'
# require 'file'

class CsvProcessor
  attr_accessor :organizers
  attr_accessor :zip_ranges

  OPEN_RANGE_SIZE = 100

  def initialize(path)
    @csv = CSV.new(File.open(path))
    @csv.shift
    @organizers = {}
    @zip_ranges = []
  end

  def run
    last_zip = -1
    last_key = nil
    current_zip_range = {}

    @csv.each_with_index do |row, idx|
      zip, key, email, nickname = process_csv_row(row)

      insert_organizer(key, email, nickname)

      if (zip - last_zip).abs < OPEN_RANGE_SIZE && last_key == key
        current_zip_range[:e] = zip
      else
        current_zip_range = {s: zip, e: zip, k: key}
        zip_ranges << current_zip_range
      end

      last_zip = zip
      last_key = key
    end
  end

  def to_json
    {
      organizers: organizers,
      zip_ranges: zip_ranges
    }.to_json
  end

  private

  def process_csv_row(row)
    zip, key, email, nickname, cc_org, name = row
    zip = zip.to_i
    [zip, key, email, nickname]
  end

  def insert_organizer(key, email, nickname)
    organizer = @organizers[key]

    if organizer.nil?
      organizer = {email: email, nickname: nickname}
      @organizers[key] = organizer
    end

    organizer
  end
end

path = ARGV[0]

processor = CsvProcessor.new(path)
processor.run

text = <<~HERE
(function () {
  window.organizers = #{processor.to_json};

  function showError(text) {
    var elt = document.getElementById('organizer-result-error');
    elt.innerText = text;
    elt.classList.remove('rov-lookup-hidden');
  }

  function hideError() {
    document.getElementById('organizer-result-error').classList.add('rov-lookup-hidden');
  }

  function hideOrganizer() {
    document.getElementById('organizer-result-success').classList.add('rov-lookup-hidden');
  }

  function displayOrganizer(organizer) {
    console.log("Success", organizer);
    document.getElementById('organizer-result-success__organizer-name').innerText = organizer['nickname'];
    var emailLink = document.getElementById('organizer-result-success__organizer-email-mailto');
    emailLink.innerText = organizer['email'];
    emailLink.href = "mailto:" + organizer['email'];
    document.getElementById('organizer-result-success').classList.remove('rov-lookup-hidden');
  }


  // Public Functions

  window.createOrganizerLookup = function(eltID) {
    var htmlString =
      '<form onsubmit="searchOrganizer(); return false;">' +
      '  Enter a zip code:<br>' +
      '  <input type="text" id="organizer-lookup-zip-code">' +
      '  <button type="submit">Search</button>' +
      '</form>' +
      '<div id="organizer-result-error" class="rov-lookup-hidden">' +
      '</div>' +
      '<div id="organizer-result-success" class="rov-lookup-hidden">' +
      '    <div style="margin-bottom: 0.5rem;">Your organizer is <span id="organizer-result-success__organizer-name"></span>.</div>' +
      '    <div>You can email them at' +
      '        <a id="organizer-result-success__organizer-email-mailto"></a>' +
      '    </div>' +
      '</div>';
      var elt = document.getElementById(eltID);
      elt.innerHTML = htmlString;
  }

  window.searchOrganizer = function() {
    hideOrganizer();

    var inputField = document.getElementById('organizer-lookup-zip-code');
    var zipCode = inputField.value.replace(/\s+/g, '');

    if (zipCode.length == 0) {
      showError("Please enter a zip code.");
      return;
    }

    var integerZip = parseInt(zipCode);

    if (integerZip && integerZip > 0) {
      var organizers = window.organizers['organizers'];
      var zipRanges = window.organizers['zip_ranges'];

      for (var i=0; i<zipRanges.length; i++) {
        var range = zipRanges[i];
        if (integerZip >= range['s'] && integerZip <= range['e']) {
          var organizer = organizers[range['k']];
          hideError();
          displayOrganizer(organizer);
          return;
        }
      }
    }

    showError("Unable to find a zip code matching '" + zipCode + "'");
  }

  function injectCSS() {
    var css = "<style type='text/css'>" +
    "#organizer-result-error {" +
        "background-color: rgb(254 202 202);" +
        "border: solid 1px rgb(239 68 68);" +
        "padding: 1rem;" +
        "margin-top: 0.5rem;" +
        "border-radius: 0.25rem;" +
        "color: rgb(69 10 10);" +
    "}" +
    "" +
    "#organizer-result-success {" +
        "background-color: rgb(236 252 203);" +
        "border: solid 1px rgb(163 230 53);" +
        "padding: 1rem;" +
        "margin-top: 0.5rem;" +
        "border-radius: 0.25rem;" +
        "color: rgb(26 46 5);" +
    "}" +
    "" +
    ".rov-lookup-hidden {" +
        "display: none;" +
    "}" +
    "</style>";
    document.head.insertAdjacentHTML("beforeend", css);
  }

  injectCSS();
})();

HERE

output_path = File.join(__dir__, "rov_lookup.js")

File.open(output_path, "w") do |f|
  f.write(text)
end

puts "Output written to #{output_path}"

puts "Use this file by adding the following HTML to any page:"
puts "Make sure you adjust the location of rov_lookup.js to reflect the realities of your server!"
puts ""

puts <<~HERE
<div id="rov-organizer-lookup-frame"></div>
<script type="text/javascript" src="./rov_lookup.js"></script>
<script>window.createOrganizerLookup('rov-organizer-lookup-frame');</script>
HERE