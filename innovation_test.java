import org.nlogo.headless.HeadlessWorkspace;



public class innovation_test {
    public static void main(String[] argv) {
        HeadlessWorkspace workspace = HeadlessWorkspace.newInstance();
        try {
            workspace.open("environment.nlogo");

            // Define the range of innovation probabilities
            double startProbability = 0;
            double endProbability = 1000;
            double increment = 5;

            // Iterate over the range of probabilities
            for (double probability = startProbability; probability <= endProbability; probability += increment) {
                workspace.command("set depositFee " + probability);
                workspace.command("setup");
                workspace.command("go");
                double maxFeasibleQuality = (double) workspace.report("landfill");

                System.out.println("deposit Fee: " + probability);
                System.out.println("Num of phones landfilled: " + maxFeasibleQuality);
                System.out.println("-----------------------------------");
            }

            workspace.dispose();
        } catch (Exception ex) {
            ex.printStackTrace();
        }
    }
}
