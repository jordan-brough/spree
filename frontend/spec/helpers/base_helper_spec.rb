require 'spec_helper'

module Spree
  describe BaseHelper do
    # Regression test for #2759
    it "spree_frontend.nested_taxons_path works with a Taxon object" do
      taxon = create(:taxon, :name => "iphone")
      spree_frontend.nested_taxons_path(taxon).should == "/t/iphone"
    end
  end
end
