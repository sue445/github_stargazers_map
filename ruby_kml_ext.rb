# ruby_kmlでstyleを使うためのモンキーパッチ
require "ruby_kml"

module KML
  class Placemark < KML::Container
    attr_accessor :style

    def render(xm=Builder::XmlMarkup.new(:indent => 2))
      xm.Placemark {
        super
        features.each { |f| f.render(xm) }
        plain_children.each { |c| xm << c }
        geometry.render(xm) unless geometry.nil?
        style.render(xm) unless style.nil?
      }
    end
  end
end
