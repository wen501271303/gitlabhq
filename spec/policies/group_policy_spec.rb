require 'spec_helper'

describe GroupPolicy do
  let(:guest) { create(:user) }
  let(:reporter) { create(:user) }
  let(:developer) { create(:user) }
  let(:master) { create(:user) }
  let(:owner) { create(:user) }
  let(:admin) { create(:admin) }
  let(:group) { create(:group) }

  let(:reporter_permissions) { [:admin_label] }

  let(:master_permissions) do
    [
      :create_projects,
      :admin_milestones
    ]
  end

  let(:owner_permissions) do
    [
      :admin_group,
      :admin_namespace,
      :admin_group_member,
      :change_visibility_level,
      :create_subgroup
    ]
  end

  before do
    group.add_guest(guest)
    group.add_reporter(reporter)
    group.add_developer(developer)
    group.add_master(master)
    group.add_owner(owner)
  end

  subject { described_class.new(current_user, group) }

  def expect_allowed(*permissions)
    permissions.each { |p| is_expected.to be_allowed(p) }
  end

  def expect_disallowed(*permissions)
    permissions.each { |p| is_expected.not_to be_allowed(p) }
  end

  context 'with no user' do
    let(:current_user) { nil }

    it do
      expect_allowed(:read_group)
      expect_disallowed(*reporter_permissions)
      expect_disallowed(*master_permissions)
      expect_disallowed(*owner_permissions)
    end
  end

  context 'guests' do
    let(:current_user) { guest }

    it do
      expect_allowed(:read_group)
      expect_disallowed(*reporter_permissions)
      expect_disallowed(*master_permissions)
      expect_disallowed(*owner_permissions)
    end
  end

  context 'reporter' do
    let(:current_user) { reporter }

    it do
      expect_allowed(:read_group)
      expect_allowed(*reporter_permissions)
      expect_disallowed(*master_permissions)
      expect_disallowed(*owner_permissions)
    end
  end

  context 'developer' do
    let(:current_user) { developer }

    it do
      expect_allowed(:read_group)
      expect_allowed(*reporter_permissions)
      expect_disallowed(*master_permissions)
      expect_disallowed(*owner_permissions)
    end
  end

  context 'master' do
    let(:current_user) { master }

    it do
      expect_allowed(:read_group)
      expect_allowed(*reporter_permissions)
      expect_allowed(*master_permissions)
      expect_disallowed(*owner_permissions)
    end
  end

  context 'owner' do
    let(:current_user) { owner }

    it do
      allow(Group).to receive(:supports_nested_groups?).and_return(true)

      expect_allowed(:read_group)
      expect_allowed(*reporter_permissions)
      expect_allowed(*master_permissions)
      expect_allowed(*owner_permissions)
    end
  end

  context 'admin' do
    let(:current_user) { admin }

    it do
      allow(Group).to receive(:supports_nested_groups?).and_return(true)

      expect_allowed(:read_group)
      expect_allowed(*reporter_permissions)
      expect_allowed(*master_permissions)
      expect_allowed(*owner_permissions)
    end
  end

  describe 'when nested group support feature is disabled' do
    before do
      allow(Group).to receive(:supports_nested_groups?).and_return(false)
    end

    context 'admin' do
      let(:current_user) { admin }

      it 'allows every owner permission except creating subgroups' do
        create_subgroup_permission = [:create_subgroup]
        updated_owner_permissions = owner_permissions - create_subgroup_permission

        expect_disallowed(*create_subgroup_permission)
        expect_allowed(*updated_owner_permissions)
      end
    end

    context 'owner' do
      let(:current_user) { owner }

      it 'allows every owner permission except creating subgroups' do
        create_subgroup_permission = [:create_subgroup]
        updated_owner_permissions = owner_permissions - create_subgroup_permission

        expect_disallowed(*create_subgroup_permission)
        expect_allowed(*updated_owner_permissions)
      end
    end
  end

  describe 'private nested group use the highest access level from the group and inherited permissions', :nested_groups do
    let(:nested_group) { create(:group, :private, parent: group) }

    before do
      nested_group.add_guest(guest)
      nested_group.add_guest(reporter)
      nested_group.add_guest(developer)
      nested_group.add_guest(master)

      group.owners.destroy_all

      group.add_guest(owner)
      nested_group.add_owner(owner)
    end

    subject { described_class.new(current_user, nested_group) }

    context 'with no user' do
      let(:current_user) { nil }

      it do
        expect_disallowed(:read_group)
        expect_disallowed(*reporter_permissions)
        expect_disallowed(*master_permissions)
        expect_disallowed(*owner_permissions)
      end
    end

    context 'guests' do
      let(:current_user) { guest }

      it do
        expect_allowed(:read_group)
        expect_disallowed(*reporter_permissions)
        expect_disallowed(*master_permissions)
        expect_disallowed(*owner_permissions)
      end
    end

    context 'reporter' do
      let(:current_user) { reporter }

      it do
        expect_allowed(:read_group)
        expect_allowed(*reporter_permissions)
        expect_disallowed(*master_permissions)
        expect_disallowed(*owner_permissions)
      end
    end

    context 'developer' do
      let(:current_user) { developer }

      it do
        expect_allowed(:read_group)
        expect_allowed(*reporter_permissions)
        expect_disallowed(*master_permissions)
        expect_disallowed(*owner_permissions)
      end
    end

    context 'master' do
      let(:current_user) { master }

      it do
        expect_allowed(:read_group)
        expect_allowed(*reporter_permissions)
        expect_allowed(*master_permissions)
        expect_disallowed(*owner_permissions)
      end
    end

    context 'owner' do
      let(:current_user) { owner }

      it do
        allow(Group).to receive(:supports_nested_groups?).and_return(true)

        expect_allowed(:read_group)
        expect_allowed(*reporter_permissions)
        expect_allowed(*master_permissions)
        expect_allowed(*owner_permissions)
      end
    end
  end

  describe 'change_share_with_group_lock' do
    context 'when the group has a parent' do
      let(:group) { create(:group, parent: parent) }

      context 'when the parent share_with_group_lock is enabled' do
        let(:parent) { create(:group, share_with_group_lock: true) }
        let(:current_user) { owner }

        context 'when current_user owns the parent' do
          before do
            parent.add_owner(owner)
          end

          it { expect_allowed(:change_share_with_group_lock) }
        end

        context 'when current_user owns the group but not the parent' do
          it { expect_disallowed(:change_share_with_group_lock) }
        end
      end

      context 'when the parent share_with_group_lock is disabled' do
        let(:parent) { create(:group) }
        let(:current_user) { owner }

        context 'when current_user owns the parent' do
          before do
            parent.add_owner(owner)
          end

          it { expect_allowed(:change_share_with_group_lock) }
        end

        context 'when current_user owns the group but not the parent' do
          it { expect_allowed(:change_share_with_group_lock) }
        end
      end
    end

    context 'when the group does not have a parent' do
      context 'when current_user owns the group' do
        let(:current_user) { owner }

        it { expect_allowed(:change_share_with_group_lock) }
      end
    end
  end
end
