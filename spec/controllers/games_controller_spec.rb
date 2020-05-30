# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  shared_examples 'kicks_anon_user' do
    it { is_expected.not_to have_http_status(200) }

    it 'sets flash alert' do
      subject
      expect(flash[:alert]).to be
    end

    it 'redirects to user log in' do
      is_expected.to redirect_to(new_user_session_path)
    end
  end

  describe 'POST #create' do
    subject { post :create }

    context 'when user is anon' do
      it { expect { subject }.not_to change(Game, :count) }

      it_behaves_like 'kicks_anon_user'
    end

    context 'when user is logged in' do
      before do
        sign_in user
        generate_questions(15)
      end

      it { expect { subject }.to change(user.games, :count).by(1) }

      it 'redirects to created game' do
        is_expected.to redirect_to(game_path(Game.last))
      end

      it 'sets flash notice' do
        subject
        expect(flash[:notice]).to be
      end

      context 'when user already has a running game' do
        before { game_w_questions }

        it { expect { subject }.not_to change(Game, :count) }

        it 'redirects to a running game' do
          is_expected.to redirect_to(game_path(game_w_questions))
        end

        it 'sets flash alert' do
          subject
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe 'GET #show' do
    subject { get :show, id: game_w_questions.id }

    context 'when user is anon' do
      it_behaves_like 'kicks_anon_user'
    end

    context 'when user is logged in' do
      before { sign_in user }

      it { is_expected.to have_http_status(200) }
      it { is_expected.to render_template(:show) }

      context 'when user tries to open another user game' do
        let(:user2) { FactoryBot.create(:user) }

        before { sign_in user2 }

        it { is_expected.not_to have_http_status(200) }

        it 'sets flash alert' do
          subject
          expect(flash[:alert]).to be
        end

        it 'redirects to root path' do
          is_expected.to redirect_to(root_path)
        end
      end
    end
  end

  describe 'PUT #answer' do
    subject { put :answer, id: game_w_questions.id, letter: 'a' }

    context 'when user is anon' do
      it_behaves_like 'kicks_anon_user'
    end

    context 'when user is logged in' do
      before { sign_in user }

      it 'pass letter to the game' do
        expect_any_instance_of(Game).to receive(:answer_current_question!).with('a')
        subject
      end

      context 'when answer is correct' do
        before { allow_any_instance_of(Game).to receive(:answer_current_question!).with('a').and_return(true) }

        it 'does not set flash' do
          subject
          expect(flash).to be_empty
        end

        context 'when game is finished' do
          before { allow_any_instance_of(Game).to receive(:finished?).and_return(true) }

          it 'redirects to user path' do
            is_expected.to redirect_to(user_path(user))
          end
        end

        context 'when game runs' do
          before { allow_any_instance_of(Game).to receive(:finished?).and_return(false) }

          it 'redirects to running game' do
            is_expected.to redirect_to(game_path(game_w_questions))
          end
        end
      end

      context 'when answer is wrong' do
        before { allow_any_instance_of(Game).to receive(:answer_current_question!).with('a').and_return(false) }

        it 'redirects to user path' do
          is_expected.to redirect_to(user_path(user))
        end

        it 'sets flash alert' do
          subject
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe 'PUT #take_money' do
    subject { put :take_money, id: game_w_questions.id }

    context 'when user is anon' do
      it_behaves_like 'kicks_anon_user'
    end

    context 'when user is logged in' do
      before { sign_in user }

      it 'calls take_money method on the game' do
        expect_any_instance_of(Game).to receive(:take_money!)
        subject
      end

      it 'redirects to user path' do
        is_expected.to redirect_to(user_path(user))
      end

      it 'sets flash warning' do
        subject
        expect(flash[:warning]).to be
      end
    end
  end

  describe 'PUT #help' do
    subject { put :help, id: game_w_questions.id, help_type: :audience_help }

    context 'when user is anon' do
      it_behaves_like 'kicks_anon_user'
    end

    context 'when user is logged in' do
      before { sign_in user }

      it 'redirects to running game path' do
        is_expected.to redirect_to(game_path(game_w_questions))
      end

      context 'when help is available' do
        before { allow_any_instance_of(Game).to receive(:use_help).with(:audience_help).and_return(true) }

        it 'sets flash info' do
          subject
          expect(flash[:info]).to be
        end
      end

      context 'when help is not available' do
        before { allow_any_instance_of(Game).to receive(:use_help).with(:audience_help).and_return(nil) }

        it 'sets flash alert' do
          subject
          expect(flash[:alert]).to be
        end
      end
    end
  end
end
