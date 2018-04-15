# Code Review plugin for Redmine
# Copyright (C) 2009-2012  Haruyuki Iida
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

RedmineApp::Application.routes.draw do

  scope 'projects/:project_id' do
    resources :code_review_assignments
    resources :code_reviews do
      member do
        post :reply
      end
      collection do
        get :preview
        get :forward_to_revision
      end
    end

    # view patching via js 'hooks'.
    get 'code_review_views/update_diff',
      to: 'code_review_views#update_diff_view',
      as: :update_diff_view_code_review

    get 'code_review_views/update_revisions',
      to: 'code_review_views#update_revisions_view',
      as: :update_revisions_view_code_review

    get 'code_review_views/update_attachment',
      to: 'code_review_views#update_attachment_view',
      as: :update_attachment_view_code_review


  end

  scope 'projects/:id' do

    match 'code_review_settings/:action', controller: 'code_review_settings',
                                          via: [:get, :post, :put, :patch]

  end
end
