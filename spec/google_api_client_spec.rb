describe GoogleApiClient do

  before do
    @google_api_client = GoogleApiClient.new(auth_file: File.join(__dir__, 'resources', 'google_auth.example.json'))
  end

  it "will raise an exception if not instantiated with a auth file" do
    expect{GoogleApiClient.new()}.to raise_error("missing auth_file")
  end

  it "DRIVE_FILE return a Google::Apis::DriveV3::File" do
    expect(GoogleApiClient::DRIVE_FILE).to equal(Google::Apis::DriveV3::File)
  end
  
end