class Railsy
  concerning :Explosions do
    def test; end
  end

  concerning "Writing" do
    def test; end
  end

  concerning(:Criminal, &block)
end
