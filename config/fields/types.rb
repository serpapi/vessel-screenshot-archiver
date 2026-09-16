# frozen_string_literal: true

# Every `field :title` in every crawler comes out stripped.
Vessel::Cargo::FieldType.add(:title) { |value| value.to_s.strip }
