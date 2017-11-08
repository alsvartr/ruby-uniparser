Gem::Specification.new do |spec|
  spec.name          = 'uniparser'
  spec.version       = '0.1'
  spec.authors       = ['Pavel Nazarov']
  spec.email         = ['nazarov.pn@gmail.com']
  spec.licenses      = ['MIT']

  spec.summary       = 'Simple and straightforward config & cli options parser library'
  spec.description   = 'Simple and straightforward config & cli options parser library'
  spec.homepage      = 'https://github.com/alsvartr/ruby-uniparser'

  spec.required_ruby_version = '>= 2.0.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1'
  spec.add_development_dependency 'rspec', '~> 3'
end
