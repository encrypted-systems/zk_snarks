pragma circom 2.0.0;

template Equation() {
    signal input x;
    signal input a;
    signal input b;
    signal input c;

    signal ax2;
    signal bx;
    signal result;

    ax2 <== x * x;

    bx <== b * x;

    result <== a * ax2 + bx + c;

    result === 0;
}

component main = Equation();