require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#json_ld_script_tag" do
    it "escapes a literal </script> in a data value so it can't break out of the surrounding script tag" do
      output = helper.json_ld_script_tag(description: "malicious </script><script>alert(1)</script> payload")

      expect(output).not_to include("</script><script>")
      # The only literal "</script>" anywhere in the rendered tag is its own
      # real closing tag, appended by content_tag at the very end — none of
      # it leaks through from the data value itself, so a description
      # containing that sequence can't prematurely terminate the wrapping
      # <script> element.
      expect(output.scan("</script>").size).to eq(1)
      expect(output).to end_with("</script>")
    end
  end
end
