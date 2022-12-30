CREATE FUNCTION
    instance_questions_update_score(
        -- identify the instance_question/submission
        IN arg_assessment_id bigint,        -- must provide assessment_id (typically considered safe for authn)
        IN arg_submission_id bigint,        -- submission_id is optional
        IN arg_instance_question_id bigint, -- must provide instance_question_id
        IN arg_modified_at timestamptz,     -- if modified_at is specified, update only if matches previous value

        -- specify what should be updated
        IN arg_score_perc double precision,
        IN arg_points double precision,
        IN arg_manual_score_perc double precision,
        IN arg_manual_points double precision,
        IN arg_auto_score_perc double precision,
        IN arg_auto_points double precision,
        IN arg_feedback jsonb,
        IN arg_partial_scores jsonb,
        IN arg_manual_rubric_grading_id bigint,
        IN arg_auto_rubric_grading_id bigint,
        IN arg_authn_user_id bigint,

        -- resulting updates
        OUT assessment_instance_id bigint, -- Used by caller to update LTI outcomes
        OUT modified_at_conflict boolean,  -- If true, grading job was created, but scores were not
        OUT grading_job_id bigint
    )
AS $$
DECLARE
    found_submission_id bigint;
    instance_question_id bigint;
    current_modified_at timestamptz;
    max_points double precision;
    max_manual_points double precision;
    max_auto_points double precision;
    manual_rubric_id bigint;
    auto_rubric_id bigint;

    current_partial_score jsonb;
    current_auto_points double precision;
    current_manual_points double precision;
    current_auto_rubric_grading_id bigint;
    current_manual_rubric_grading_id bigint;

    new_score_perc double precision;
    new_auto_score_perc double precision;
    new_points double precision;
    new_manual_points double precision;
    new_auto_points double precision;
    new_correct boolean;
BEGIN
    -- ##################################################################
    -- get the assessment_instance, max_points, and (possibly) submission_id

    SELECT
        s.id,
        iq.id,
        ai.id,
        aq.max_points,
        aq.max_auto_points,
        aq.max_manual_points,
        aq.manual_rubric_id,
        aq.auto_rubric_id,
        s.partial_scores,
        iq.auto_points,
        iq.manual_points,
        iq.auto_rubric_grading_id,
        iq.manual_rubric_grading_id,
        iq.modified_at
    INTO
        found_submission_id,
        instance_question_id,
        assessment_instance_id,
        max_points,
        max_auto_points,
        max_manual_points,
        manual_rubric_id,
        auto_rubric_id,
        current_partial_score,
        current_auto_points,
        current_manual_points,
        current_auto_rubric_grading_id,
        current_manual_rubric_grading_id,
        current_modified_at
    FROM
        instance_questions AS iq
        JOIN assessment_questions AS aq ON (aq.id = iq.assessment_question_id)
        JOIN questions AS q on (q.id = aq.question_id)
        JOIN assessment_instances AS ai ON (ai.id = iq.assessment_instance_id)
        JOIN assessments AS a ON (a.id = ai.assessment_id)
        LEFT JOIN variants AS v ON (v.instance_question_id = iq.id)
        LEFT JOIN submissions AS s ON (s.variant_id = v.id)
    WHERE
        a.id = arg_assessment_id
        AND iq.id = arg_instance_question_id
        AND (s.id = arg_submission_id OR arg_submission_id IS NULL)
    ORDER BY s.date DESC, ai.number DESC;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'could not locate submission_id=%, instance_question_id=% assessment_id=%', arg_submission_id, arg_instance_question_id, arg_assessment_id;
    END IF;

    modified_at_conflict = arg_modified_at IS NOT NULL AND current_modified_at != arg_modified_at;

    -- ##################################################################
    -- if rubric grading has been provided, it overrides the points

    IF manual_rubric_id IS NOT NULL AND arg_manual_rubric_grading_id IS NOT NULL THEN
        SELECT computed_points, NULL
        INTO arg_manual_points, arg_manual_score_perc
        FROM rubric_gradings rg
        WHERE rg.id = arg_manual_rubric_grading_id;
    ELSIF manual_rubric_id IS NOT NULL AND arg_points IS NULL AND arg_score_perc IS NULL AND
          arg_manual_score_perc IS NULL AND arg_manual_points IS NULL THEN
        -- If there is a rubric, and the manual_points will not be
        -- updated, keep the current rubric grading.
        arg_manual_rubric_grading_id := current_manual_rubric_grading_id;
    ELSE
        -- If the manual_points will be updated and the rubric grading
        -- has not been set, clear the rubric grading.
        arg_manual_rubric_grading_id := NULL;
    END IF;

    IF auto_rubric_id IS NOT NULL AND arg_auto_rubric_grading_id IS NOT NULL THEN
        SELECT computed_points, NULL
        INTO arg_auto_points, arg_auto_score_perc
        FROM rubric_gradings rg
        WHERE rg.id = arg_auto_rubric_grading_id;
    ELSIF auto_rubric_id IS NOT NULL AND arg_partial_scores IS NULL AND
          arg_auto_score_perc IS NULL AND arg_auto_points IS NULL THEN
        -- If there is a rubric, and the auto_points will not be
        -- updated, keep the current rubric grading.
        arg_auto_rubric_grading_id := current_auto_rubric_grading_id;
    ELSE
        -- If the auto_points will be updated and the rubric grading
        -- has not been set, clear the rubric grading.
        arg_auto_rubric_grading_id := NULL;
    END IF;

    -- ##################################################################
    -- check if partial_scores is an object

    new_points := NULL;
    new_score_perc := NULL;
    new_auto_score_perc := NULL;
    new_auto_points := NULL;
    new_manual_points := NULL;

    IF arg_partial_scores IS NOT NULL THEN
        IF jsonb_typeof(arg_partial_scores) != 'object' THEN
            RAISE EXCEPTION 'partial_scores is not an object';
        END IF;
        IF current_partial_score IS NOT NULL THEN
            arg_partial_scores = current_partial_score || arg_partial_scores;
        END IF;
        SELECT SUM(COALESCE((val->'score')::DOUBLE PRECISION, 0) *
                   COALESCE((val->'weight')::DOUBLE PRECISION, 1)) * 100 /
               SUM(COALESCE((val->'weight')::DOUBLE PRECISION, 1))
          INTO new_auto_score_perc
          FROM jsonb_each(arg_partial_scores) AS p(k, val);
        new_auto_points := new_auto_score_perc / 100 * max_auto_points;
    END IF;

    -- ##################################################################
    -- compute the new score_perc/points

    IF arg_auto_score_perc IS NOT NULL THEN
        IF arg_auto_points IS NOT NULL THEN RAISE EXCEPTION 'Cannot set both auto_score_perc and auto_points'; END IF;
        IF arg_score_perc IS NOT NULL THEN RAISE EXCEPTION 'Cannot set both auto_score_perc and score_perc'; END IF;
        new_auto_score_perc := arg_auto_score_perc;
        new_auto_points := new_auto_score_perc / 100 * max_auto_points;
    ELSIF arg_auto_points IS NOT NULL THEN
        IF arg_points IS NOT NULL THEN RAISE EXCEPTION 'Cannot set both auto_points and points'; END IF;
        new_auto_points := arg_auto_points;
        new_auto_score_perc := (CASE WHEN max_auto_points > 0 THEN new_auto_points / max_auto_points ELSE 0 END) * 100;
    END IF;

    IF new_auto_score_perc IS NOT NULL THEN new_correct := new_auto_score_perc > 50; END IF;

    IF arg_manual_score_perc IS NOT NULL THEN
        IF arg_manual_points IS NOT NULL THEN RAISE EXCEPTION 'Cannot set both manual_score_perc and manual_points'; END IF;
        IF arg_score_perc IS NOT NULL THEN RAISE EXCEPTION 'Cannot set both manual_score_perc and score_perc'; END IF;
        new_manual_points := arg_manual_score_perc / 100 * max_manual_points;
        new_points := new_manual_points + COALESCE(new_auto_points, current_auto_points, 0);
        new_score_perc := (CASE WHEN max_points > 0 THEN new_points / max_points ELSE 0 END) * 100;
    ELSIF arg_manual_points IS NOT NULL THEN
        IF arg_points IS NOT NULL THEN RAISE EXCEPTION 'Cannot set both manual_points and points'; END IF;
        new_manual_points := arg_manual_points;
        new_points := new_manual_points + COALESCE(new_auto_points, current_auto_points, 0);
        new_score_perc := (CASE WHEN max_points > 0 THEN new_points / max_points ELSE 0 END) * 100;
    ELSIF arg_score_perc IS NOT NULL THEN
        IF arg_points IS NOT NULL THEN RAISE EXCEPTION 'Cannot set both score_perc and points'; END IF;
        new_score_perc := arg_score_perc;
        new_points := new_score_perc / 100 * max_points;
        new_manual_points := new_points - COALESCE(new_auto_points, current_auto_points, 0);
    ELSIF arg_points IS NOT NULL THEN
        new_points := arg_points;
        new_score_perc := (CASE WHEN max_points > 0 THEN new_points / max_points ELSE 0 END) * 100;
        new_manual_points := new_points - COALESCE(new_auto_points, current_auto_points, 0);
    ELSEIF new_auto_points IS NOT NULL THEN
        new_points := COALESCE(current_manual_points, 0) + new_auto_points;
        new_score_perc := (CASE WHEN max_points > 0 THEN new_points / max_points ELSE 0 END) * 100;
    END IF;

    -- ##################################################################
    -- if we were originally provided a submission_id or we have feedback
    -- or partial scores, create a grading job and update the submission

    IF found_submission_id IS NOT NULL
    AND (
        found_submission_id = arg_submission_id
        OR new_score_perc IS NOT NULL
        OR arg_feedback IS NOT NULL
        OR arg_partial_scores IS NOT NULL
    ) THEN
        INSERT INTO grading_jobs
            (submission_id, auth_user_id, graded_by, graded_at, grading_method,
             correct, score, auto_points, manual_points,
             feedback, partial_scores, manual_rubric_grading_id, auto_rubric_grading_id)
        VALUES
            (found_submission_id, arg_authn_user_id, arg_authn_user_id, now(), 'Manual',
             new_correct, new_score_perc / 100, new_auto_points, new_manual_points,
             arg_feedback, arg_partial_scores, arg_manual_rubric_grading_id, arg_auto_rubric_grading_id)
        RETURNING id INTO grading_job_id;

        IF NOT modified_at_conflict THEN
            UPDATE submissions AS s
            SET
                feedback = CASE
                    WHEN feedback IS NULL THEN arg_feedback
                    WHEN arg_feedback IS NULL THEN feedback
                    WHEN jsonb_typeof(feedback) = 'object' AND jsonb_typeof(arg_feedback) = 'object' THEN feedback || arg_feedback
                    ELSE arg_feedback
                END,
                partial_scores = CASE
                    WHEN arg_partial_scores IS NULL THEN partial_scores
                    ELSE arg_partial_scores
                END,
                graded_at = now(),
                override_score = COALESCE(new_auto_score_perc / 100, override_score),
                score = COALESCE(new_auto_score_perc / 100, score),
                correct = COALESCE(new_correct, correct),
                gradable = CASE WHEN new_auto_score_perc IS NULL THEN gradable ELSE TRUE END
            WHERE s.id = found_submission_id;
        END IF;
    END IF;

    -- ##################################################################
    -- do the score update of the instance_question, log it, and update the assessment_instance, if we have a new_score

    IF new_score_perc IS NOT NULL AND NOT modified_at_conflict THEN
        UPDATE instance_questions AS iq
        SET
            points = new_points,
            score_perc = new_score_perc,
            auto_points = COALESCE(new_auto_points, auto_points),
            manual_points = COALESCE(new_manual_points, manual_points),
            auto_rubric_grading_id = arg_auto_rubric_grading_id,
            manual_rubric_grading_id = arg_manual_rubric_grading_id,
            status = 'complete',
            modified_at = now(),
            highest_submission_score = COALESCE(new_auto_score_perc / 100, highest_submission_score),
            requires_manual_grading = FALSE,
            last_grader = arg_authn_user_id
        WHERE iq.id = instance_question_id;

        INSERT INTO question_score_logs
            (instance_question_id, auth_user_id,
            max_points, max_manual_points, max_auto_points,
            points, score_perc, auto_points, manual_points)
        VALUES
            (instance_question_id, arg_authn_user_id,
            max_points, max_manual_points, max_auto_points,
            new_points, new_score_perc, new_auto_points, new_manual_points);

        PERFORM assessment_instances_grade(assessment_instance_id, arg_authn_user_id, credit => 100, allow_decrease => true);
    END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;
