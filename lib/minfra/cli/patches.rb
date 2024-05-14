require 'highline/import'
module HieraPatch
  def hiera?
    false
  end
end
require 'hiera/backend/eyaml/encryptors/gpg'

Hiera::Backend::Eyaml::Encryptors::Gpg.extend(HieraPatch)
