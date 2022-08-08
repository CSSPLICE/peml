require "dottie/ext"
class GenerateTests

    def generate_tests
        Dir.glob(File.expand_path('test/peml/*.peml', __FILE__)).each do |f|
            file = File.basename(f)
            parsed_peml = Peml::parse({filename: f})
            value=parsed_peml.dottie!
            File.write("parsed_tests/#{file}_test.txt", value['assets.test.files'][0]['parsed_tests'])
        end
    end
end