classdef tools
    methods  (Static)
        function ber = calculate_ber(x, y)
            [~, ber] = biterr(x, y);
        end

        function rate = calculate_error_percent(x, y)
            [~, ber] = biterr(x, y);
            rate = ber * 100;
        end
    end
end