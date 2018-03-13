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
  scope 'projects/:id' do

    # the goal
    # resources :code_reviews

    get    'code_reviews',     to: 'code_review#index',  as: :code_reviews
    get    'code_reviews/new', to: 'code_review#new',    as: :new_code_review
    post   'code_reviews', to: 'code_review#create'

    patch  'code_reviews/:review_id', to: 'code_review#update'
    delete 'code_reviews/:review_id', to: 'code_review#destroy'

    post   'code_reviews/:review_id/reply', to: 'code_review#reply', as: :reply_code_review

    get    'code_reviews/:review_id', to: 'code_review#show',   as: :code_review

    match 'code_review/preview',
      to: 'code_review#preview',
      via: [:get, :post],
      as: :preview_code_review


    # code_review_assignments should be a separate resource
    # resources :code_review_assignments
    get 'code_review_assignments/new',
      to: 'code_review#assign',
      as: :new_code_review_assignment
    get    'code_review_assignments/:assignment_id', to: 'code_review#show',   as: :code_review_assignment


    # not sure where this belongs
    get 'code_review/forward_to_revision',
      to: 'code_review#forward_to_revision',
      as: :forward_to_revision_code_review


    # view patching via js 'hooks'. Maybe separate controller as well.
    get 'code_review_views/update_diff',
      to: 'code_review#update_diff_view',
      as: :update_diff_view_code_review

    get 'code_review_views/update_revisions',
      to: 'code_review#update_revisions_view',
      as: :update_revisions_view_code_review

    get 'code_review_views/update_attachment',
      to: 'code_review#update_attachment_view',
      as: :update_attachment_view_code_review


    #match 'code_review/:action', controller: 'code_review',
    #                             via: [:get, :post]

    match 'code_review_settings/:action', controller: 'code_review_settings',
                                          via: [:get, :post, :put, :patch]

  end
end
