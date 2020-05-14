# (c) goodprogrammer.ru

# Стандартный rspec-овский помощник для rails-проекта
require 'rails_helper'

# Наш собственный класс с вспомогательными методами
require 'support/my_spec_helper'

# Тестовый сценарий для модели Игры
#
# В идеале — все методы должны быть покрыты тестами, в этом классе содержится
# ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # Пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # Игра с прописанными игровыми вопросами
  let(:game_w_questions) do
    FactoryBot.create(:game_with_questions, user: user)
  end

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # Генерим 60 вопросов с 4х запасом по полю level, чтобы проверить работу
      # RANDOM при создании игры.
      generate_questions(60)

      game = nil

      # Создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
        # Проверка: Game.count изменился на 1 (создали в базе 1 игру)
      }.to change(Game, :count).by(1).and(
        # GameQuestion.count +15
        change(GameQuestion, :count).by(15).and(
          # Game.count не должен измениться
          change(Question, :count).by(0)
        )
      )

      # Проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)

      # Проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # Тесты на основную игровую логику
  context 'game mechanics' do
    # Правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # Текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # Перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)

      expect(game_w_questions.current_game_question).not_to eq(q)

      # Игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    describe 'a gamer takes money' do
      context 'even not having answered the 1st question' do
        it 'should not change their balance' do
          expect { game_w_questions.take_money! }.
            to change(user, :balance).by(0).and(
              change(game_w_questions, :status).from(:in_progress).to(:money))
          expect(game_w_questions.finished?).to be_truthy
        end
      end

      context 'after answering the 1st question correctly' do
        it 'should change their balance' do
          prize = Game::PRIZES[game_w_questions.current_level]

          q = game_w_questions.current_game_question
          game_w_questions.answer_current_question!(q.correct_answer_key)

          expect { game_w_questions.take_money! }.
            to change(user, :balance).by(prize).and(
              change(game_w_questions, :status).from(:in_progress).to(:money))
          expect(game_w_questions.finished?).to be_truthy
        end
      end
    end
  end

  context 'instance methods' do
    describe '#status' do
      it 'returns :in_progress' do
        expect(game_w_questions.status).to eq :in_progress
      end

      it 'returns :money' do
        game_w_questions.take_money!

        expect(game_w_questions.status).to eq :money
      end

      it 'returns :fail' do
        q = game_w_questions.current_game_question
        wrong_answer_key = (q.variants.keys - [q.correct_answer_key]).first
        game_w_questions.answer_current_question!(wrong_answer_key)

        expect(game_w_questions.status).to eq :fail
      end

      it 'returns :timeout' do
        game_w_questions.created_at = 1.day.ago
        q = game_w_questions.current_game_question
        wrong_answer_key = (q.variants.keys - [q.correct_answer_key]).first
        game_w_questions.answer_current_question!(wrong_answer_key)

        expect(game_w_questions.status).to eq :timeout
      end

      it 'returns :won' do
        15.times do |i|
          q = game_w_questions.current_game_question
          game_w_questions.answer_current_question!(q.correct_answer_key)
        end

        expect(game_w_questions.status).to eq :won
      end
    end
  end
end
