const db = require('../config/db');

class QuizAnswerError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function readAnswers(value) {
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch (_) {
      return [];
    }
  }
  return [];
}

function answerQuestionId(answer) {
  return answer?.question_id ?? answer?.questionId;
}

function answerSelectedIndex(answer) {
  return answer?.selected_index ?? answer?.selectedIndex;
}

async function submitQuizAnswer({ quizId, questionId, userId, selectedIndex }) {
  const isUuid = (value) => typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
  if (!isUuid(quizId) || !isUuid(questionId) || !isUuid(userId)) {
    throw new QuizAnswerError(400, 'Valid quiz, question, and participant IDs are required');
  }
  if (!Number.isInteger(selectedIndex) || selectedIndex < 0) {
    throw new QuizAnswerError(400, 'selected_index must be a non-negative integer');
  }

  const client = await db.connect();
  let transactionOpen = false;
  try {
    await client.query('BEGIN');
    transactionOpen = true;

    const { rows: quizzes } = await client.query(
      `SELECT status, mode, current_question,
         EXTRACT(EPOCH FROM (NOW() - question_started_at)) AS elapsed_seconds
       FROM quizzes WHERE id = $1 FOR SHARE`,
      [quizId]
    );
    if (!quizzes.length) throw new QuizAnswerError(404, 'Quiz not found');

    const { rows: questions } = await client.query(
      'SELECT id, options FROM quiz_questions WHERE id = $1 AND quiz_id = $2',
      [questionId, quizId]
    );
    if (!questions.length) throw new QuizAnswerError(404, 'Question does not belong to this quiz');

    const { rows: participants } = await client.query(
      `SELECT answers, total_score FROM quiz_participants
       WHERE quiz_id = $1 AND user_id = $2 FOR UPDATE`,
      [quizId, userId]
    );
    if (!participants.length) throw new QuizAnswerError(400, 'Join quiz first');

    const answers = readAnswers(participants[0].answers);
    const previousAnswer = answers.find((answer) => String(answerQuestionId(answer)) === String(questionId));
    if (previousAnswer) {
      if (Number(answerSelectedIndex(previousAnswer)) !== selectedIndex) {
        throw new QuizAnswerError(409, 'This question has already been answered');
      }
      const options = typeof questions[0].options === 'string'
        ? JSON.parse(questions[0].options)
        : questions[0].options;
      await client.query('COMMIT');
      transactionOpen = false;
      return {
        isCorrect: previousAnswer.isCorrect === true,
        score: Number(previousAnswer.score) || 0,
        correctIndex: Number.isInteger(previousAnswer.correct_index)
          ? previousAnswer.correct_index
          : options.findIndex((option) => option.isCorrect === true),
        alreadySubmitted: true,
      };
    }

    const quiz = quizzes[0];
    if (quiz.mode !== 'live' || quiz.status !== 'live') throw new QuizAnswerError(409, 'Quiz is not live');
    const questionIndex = Number(quiz.current_question) || 0;
    const { rows: activeQuestions } = await client.query(
      `SELECT id FROM quiz_questions WHERE quiz_id = $1
       ORDER BY order_index ASC, id ASC OFFSET $2 LIMIT 1`,
      [quizId, questionIndex]
    );
    if (!activeQuestions.length || String(activeQuestions[0].id) !== String(questionId)) {
      throw new QuizAnswerError(409, 'Question is not currently active');
    }

    const options = typeof questions[0].options === 'string'
      ? JSON.parse(questions[0].options)
      : questions[0].options;
    if (!Array.isArray(options) || selectedIndex >= options.length) {
      throw new QuizAnswerError(400, 'selected_index is outside the available options');
    }

    const isCorrect = options[selectedIndex]?.isCorrect === true;
    const rawElapsed = quiz.elapsed_seconds == null ? Number.NaN : Number(quiz.elapsed_seconds);
    if (Number.isFinite(rawElapsed) && rawElapsed > 20) {
      throw new QuizAnswerError(409, 'Answer window is closed');
    }
    const timeTaken = Number.isFinite(rawElapsed) ? Math.min(Math.max(rawElapsed, 0), 20) : 20;
    const score = isCorrect ? Math.round(100 + (50 * (1 - timeTaken / 20))) : 0;
    const correctIndex = options.findIndex((option) => option.isCorrect === true);
    const newAnswers = [
      ...answers,
      { question_id: questionId, selected_index: selectedIndex, isCorrect, time_taken: timeTaken, score, correct_index: correctIndex },
    ];

    await client.query(
      `UPDATE quiz_participants SET answers = $1::jsonb, total_score = COALESCE(total_score, 0) + $2
       WHERE quiz_id = $3 AND user_id = $4`,
      [JSON.stringify(newAnswers), score, quizId, userId]
    );
    await client.query('COMMIT');
    transactionOpen = false;
    return { isCorrect, score, correctIndex, alreadySubmitted: false };
  } catch (err) {
    if (transactionOpen) await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { submitQuizAnswer, QuizAnswerError };
