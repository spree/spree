# https://github.com/activerecord-hackery/ransack/commit/04254287f978cf4d78e975d36a25389b5cb581e9
# after next Ransack release we can remove this hack
module RansackSortLinkRails6Fix
  def parameters_hash(params)
    if ::ActiveRecord::VERSION::MAJOR >= 5 && params.respond_to?(:to_unsafe_h)
      params.to_unsafe_h
    else
      params
    end
  end
end

Ransack::Helpers::FormHelper::SortLink.prepend RansackSortLinkRails6Fix
